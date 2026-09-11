import type {
  ChangeRequest,
  CtsAdapter,
  CtsObject,
  ExtractFilters,
  ExtractResult,
} from "../lib/types.js";

type RfcClient = {
  open: () => Promise<void>;
  close: () => Promise<void>;
  call: (fm: string, params: Record<string, unknown>) => Promise<Record<string, unknown>>;
};

type RfcClientCtor = new (params: Record<string, string>) => RfcClient;

type HeaderRow = {
  trkorr: string;
  trfunction: string;
  trstatus: string;
  as4user: string;
  as4date: string;
  as4time: string;
  tarsystem: string;
};

const OPTION_WIDTH = 72;
const TRKORR_CHUNK = 40;

function connectionParams(): Record<string, string> {
  if (process.env.SAP_DEST) {
    return { dest: process.env.SAP_DEST };
  }
  const required = ["SAP_ASHOST", "SAP_SYSNR", "SAP_CLIENT", "SAP_USER", "SAP_PASSWD"] as const;
  for (const key of required) {
    if (!process.env[key]) {
      throw new Error(`Missing ${key}. Set RFC env vars or use CTS_ADAPTER=mock.`);
    }
  }
  return {
    ashost: process.env.SAP_ASHOST!,
    sysnr: process.env.SAP_SYSNR!,
    client: process.env.SAP_CLIENT!,
    user: process.env.SAP_USER!,
    passwd: process.env.SAP_PASSWD!,
    lang: process.env.SAP_LANG || "EN",
  };
}

function toYmd(raw?: string): string | undefined {
  if (!raw) return undefined;
  const digits = raw.replace(/\D/g, "");
  return digits.length === 8 ? digits : undefined;
}

function asString(value: unknown): string {
  if (value == null) return "";
  return String(value).trim();
}

function mapObjects(raw: unknown): CtsObject[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((row) => {
    const r = row as Record<string, unknown>;
    return {
      pgmid: asString(r.PGMID ?? r.pgmid),
      object: asString(r.OBJECT ?? r.object),
      objName: asString(r.OBJ_NAME ?? r.OBJNAME ?? r.obj_name ?? r.objName),
    };
  });
}

function parseFields(fieldsRaw: unknown): string[] {
  if (!Array.isArray(fieldsRaw)) return [];
  return fieldsRaw.map((f) => {
    if (typeof f === "string") return f;
    if (f && typeof f === "object" && "FIELDNAME" in f) {
      return asString((f as { FIELDNAME: unknown }).FIELDNAME);
    }
    return "";
  });
}

function parseDataRows(dataRaw: unknown, fieldNames: string[]): Record<string, string>[] {
  if (!Array.isArray(dataRaw)) return [];
  return dataRaw.map((row) => {
    let wa = "";
    if (typeof row === "string") wa = row;
    else if (row && typeof row === "object" && "WA" in row) {
      wa = String((row as { WA: unknown }).WA ?? "");
    }
    const parts = wa.split("|");
    const out: Record<string, string> = {};
    fieldNames.forEach((name, i) => {
      out[name] = asString(parts[i]);
    });
    return out;
  });
}

/** RFC_READ_TABLE OPTIONS lines are limited to 72 characters. */
function pushOptionLines(lines: Array<{ TEXT: string }>, text: string): void {
  for (let i = 0; i < text.length; i += OPTION_WIDTH) {
    lines.push({ TEXT: text.slice(i, i + OPTION_WIDTH) });
  }
}

function headerFilterOptions(filters: ExtractFilters): Array<{ TEXT: string }> {
  const from = toYmd(filters.dateFrom) ?? "19000101";
  const to = toYmd(filters.dateTo) ?? "99991231";
  const options: Array<{ TEXT: string }> = [];
  pushOptionLines(options, `AS4DATE GE '${from}' AND AS4DATE LE '${to}'`);
  options.push({ TEXT: `AND STRKORR EQ ' '` });
  if (filters.owner?.trim()) {
    options.push({
      TEXT: `AND AS4USER EQ '${filters.owner.trim().toUpperCase().replace(/'/g, "''")}'`,
    });
  }
  if (filters.status?.trim()) {
    options.push({
      TEXT: `AND TRSTATUS EQ '${filters.status.trim().toUpperCase().replace(/'/g, "''")}'`,
    });
  }
  if (filters.category?.trim()) {
    options.push({
      TEXT: `AND TRFUNCTION EQ '${filters.category.trim().toUpperCase().replace(/'/g, "''")}'`,
    });
  }
  return options;
}

/** Build TRKORR EQ … OR … OPTIONS for a chunk of request ids. */
function trkorrOptions(ids: string[]): Array<{ TEXT: string }> {
  const lines: Array<{ TEXT: string }> = [];
  ids.forEach((id, index) => {
    const escaped = id.replace(/'/g, "''");
    const piece =
      index === 0 ? `TRKORR EQ '${escaped}'` : ` OR TRKORR EQ '${escaped}'`;
    if (lines.length === 0) {
      lines.push({ TEXT: piece.slice(0, OPTION_WIDTH) });
      return;
    }
    const last = lines[lines.length - 1]!;
    if (last.TEXT.length + piece.length <= OPTION_WIDTH) {
      last.TEXT += piece;
    } else {
      lines.push({ TEXT: piece.trimStart().slice(0, OPTION_WIDTH) });
    }
  });
  return lines;
}

async function rfcReadTable(
  client: RfcClient,
  queryTable: string,
  fields: string[],
  options: Array<{ TEXT: string }>,
  rowCount: number,
): Promise<Record<string, string>[]> {
  const result = await client.call("RFC_READ_TABLE", {
    QUERY_TABLE: queryTable,
    DELIMITER: "|",
    ROWCOUNT: rowCount,
    FIELDS: fields.map((FIELDNAME) => ({ FIELDNAME })),
    OPTIONS: options,
  });
  const parsedNames = parseFields(result.FIELDS);
  const fieldNames = parsedNames.length ? parsedNames : fields;
  return parseDataRows(result.DATA, fieldNames);
}

async function readHeaders(
  client: RfcClient,
  filters: ExtractFilters,
): Promise<HeaderRow[]> {
  if (filters.requests?.length) {
    const ids = [
      ...new Set(filters.requests.map((r) => r.trim().toUpperCase()).filter(Boolean)),
    ];
    const max = filters.max && filters.max > 0 ? filters.max : 500;
    const limited = ids.slice(0, max);
    const rows: HeaderRow[] = [];
    for (let i = 0; i < limited.length; i += TRKORR_CHUNK) {
      const chunk = limited.slice(i, i + TRKORR_CHUNK);
      const data = await rfcReadTable(
        client,
        "E070",
        ["TRKORR", "TRFUNCTION", "TRSTATUS", "AS4USER", "AS4DATE", "AS4TIME", "TARSYSTEM"],
        trkorrOptions(chunk),
        0,
      );
      for (const r of data) {
        const trkorr = r.TRKORR ?? "";
        if (!trkorr) continue;
        rows.push({
          trkorr,
          trfunction: r.TRFUNCTION ?? "",
          trstatus: r.TRSTATUS ?? "",
          as4user: r.AS4USER ?? "",
          as4date: r.AS4DATE ?? "",
          as4time: r.AS4TIME ?? "",
          tarsystem: r.TARSYSTEM ?? "",
        });
      }
    }
    // Preserve caller order for explicit IDs
    const byId = new Map(rows.map((r) => [r.trkorr, r]));
    return limited
      .map(
        (id) =>
          byId.get(id) ?? {
            trkorr: id,
            trfunction: "",
            trstatus: "",
            as4user: "",
            as4date: "",
            as4time: "",
            tarsystem: "",
          },
      )
      .filter((r) => r.trkorr);
  }

  const max = filters.max && filters.max > 0 ? filters.max : 500;
  const data = await rfcReadTable(
    client,
    "E070",
    ["TRKORR", "TRFUNCTION", "TRSTATUS", "AS4USER", "AS4DATE", "AS4TIME", "TARSYSTEM"],
    headerFilterOptions(filters),
    max,
  );
  return data
    .map((r) => ({
      trkorr: r.TRKORR ?? "",
      trfunction: r.TRFUNCTION ?? "",
      trstatus: r.TRSTATUS ?? "",
      as4user: r.AS4USER ?? "",
      as4date: r.AS4DATE ?? "",
      as4time: r.AS4TIME ?? "",
      tarsystem: r.TARSYSTEM ?? "",
    }))
    .filter((r) => r.trkorr);
}

async function readTextsChunked(
  client: RfcClient,
  ids: string[],
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  for (let i = 0; i < ids.length; i += TRKORR_CHUNK) {
    const chunk = ids.slice(i, i + TRKORR_CHUNK);
    const rows = await rfcReadTable(
      client,
      "E07T",
      ["TRKORR", "AS4TEXT"],
      trkorrOptions(chunk),
      0,
    );
    for (const r of rows) {
      const id = r.TRKORR ?? "";
      if (id && !map.has(id)) map.set(id, r.AS4TEXT ?? "");
    }
  }
  return map;
}

async function readObjectsChunked(
  client: RfcClient,
  ids: string[],
): Promise<Map<string, CtsObject[]>> {
  const map = new Map<string, CtsObject[]>();
  for (let i = 0; i < ids.length; i += TRKORR_CHUNK) {
    const chunk = ids.slice(i, i + TRKORR_CHUNK);
    const rows = await rfcReadTable(
      client,
      "E071",
      ["TRKORR", "PGMID", "OBJECT", "OBJ_NAME"],
      trkorrOptions(chunk),
      0,
    );
    for (const r of rows) {
      const id = r.TRKORR ?? "";
      if (!id) continue;
      const list = map.get(id) ?? [];
      list.push({
        pgmid: r.PGMID ?? "",
        object: r.OBJECT ?? "",
        objName: r.OBJ_NAME ?? "",
      });
      map.set(id, list);
    }
  }
  return map;
}

async function extractViaTables(
  client: RfcClient,
  filters: ExtractFilters,
): Promise<ExtractResult> {
  const headers = await readHeaders(client, filters);
  const ids = headers.map((h) => h.trkorr);
  const texts = ids.length ? await readTextsChunked(client, ids) : new Map<string, string>();
  const objects =
    filters.includeObjects === false || ids.length === 0
      ? new Map<string, CtsObject[]>()
      : await readObjectsChunked(client, ids);

  const requests: ChangeRequest[] = headers.map((h) => ({
    request: h.trkorr,
    description: texts.get(h.trkorr) ?? "",
    category: h.trfunction,
    client: "",
    owner: h.as4user,
    status: h.trstatus,
    as4date: h.as4date,
    as4time: h.as4time,
    tarsystem: h.tarsystem,
    retcode: "000",
    message: "",
    objects: objects.get(h.trkorr) ?? [],
  }));

  return {
    adapter: "rfc",
    fetchedAt: new Date().toISOString(),
    requests,
    ok: requests.length,
    failed: 0,
  };
}

async function readChangeRequest(
  client: RfcClient,
  request: string,
): Promise<ChangeRequest> {
  const result = await client.call("CTS_API_READ_CHANGE_REQUEST", {
    REQUEST: request,
    OBJECTS: [],
  });

  return {
    request,
    description: asString(result.DESCRIPTION),
    category: asString(result.CATEGORY),
    client: asString(result.CLIENT),
    owner: asString(result.OWNER),
    status: asString(result.STATUS),
    as4date: "",
    as4time: "",
    tarsystem: "",
    retcode: asString(result.RETCODE) || "000",
    message: asString(result.MESSAGE),
    objects: mapObjects(result.OBJECTS),
  };
}

async function extractViaFm(
  client: RfcClient,
  filters: ExtractFilters,
): Promise<ExtractResult> {
  const headers = await readHeaders(client, filters);
  const requests: ChangeRequest[] = [];

  for (const h of headers) {
    try {
      const row = await readChangeRequest(client, h.trkorr);
      row.as4date = h.as4date;
      row.as4time = h.as4time;
      row.tarsystem = h.tarsystem;
      if (filters.includeObjects === false) {
        row.objects = [];
      }
      requests.push(row);
    } catch (err) {
      requests.push({
        request: h.trkorr,
        description: "",
        category: h.trfunction,
        client: "",
        owner: h.as4user,
        status: h.trstatus,
        as4date: h.as4date,
        as4time: h.as4time,
        tarsystem: h.tarsystem,
        retcode: "999",
        message: err instanceof Error ? err.message : String(err),
        objects: [],
      });
    }
  }

  const failed = requests.filter((r) => r.retcode && r.retcode !== "000").length;
  return {
    adapter: "rfc",
    fetchedAt: new Date().toISOString(),
    requests,
    ok: requests.length - failed,
    failed,
  };
}

export class RfcAdapter implements CtsAdapter {
  readonly name = "rfc" as const;

  async extract(filters: ExtractFilters): Promise<ExtractResult> {
    let Client: RfcClientCtor;
    try {
      const mod = (await import("node-rfc")) as { Client: RfcClientCtor };
      Client = mod.Client;
    } catch {
      throw new Error(
        "node-rfc is not available. Install the SAP NWRFC SDK, then `npm install node-rfc`, or set CTS_ADAPTER=mock.",
      );
    }

    const client = new Client(connectionParams());
    await client.open();

    try {
      if (filters.useFm === true) {
        return await extractViaFm(client, filters);
      }
      return await extractViaTables(client, filters);
    } finally {
      await client.close().catch(() => undefined);
    }
  }
}
