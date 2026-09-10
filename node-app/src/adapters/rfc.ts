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

function mapObjects(raw: unknown): CtsObject[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((row) => {
    const r = row as Record<string, unknown>;
    return {
      pgmid: String(r.PGMID ?? r.pgmid ?? ""),
      object: String(r.OBJECT ?? r.object ?? ""),
      objName: String(r.OBJ_NAME ?? r.OBJNAME ?? r.obj_name ?? r.objName ?? ""),
    };
  });
}

async function listRequestIds(
  client: RfcClient,
  filters: ExtractFilters,
): Promise<string[]> {
  if (filters.requests?.length) {
    return [...new Set(filters.requests.map((r) => r.trim().toUpperCase()).filter(Boolean))];
  }

  const max = filters.max && filters.max > 0 ? filters.max : 500;
  const from = toYmd(filters.dateFrom) ?? "19000101";
  const to = toYmd(filters.dateTo) ?? "99991231";

  // RFC_READ_TABLE against E070 — headers only (STRKORR blank).
  // Note: OPTIONS length is limited; keep predicates short.
  const options: Array<{ TEXT: string }> = [
    { TEXT: `AS4DATE GE '${from}' AND AS4DATE LE '${to}'` },
    { TEXT: `AND STRKORR EQ ' '` },
  ];
  if (filters.owner) {
    options.push({ TEXT: `AND AS4USER EQ '${filters.owner.toUpperCase()}'` });
  }
  if (filters.status) {
    options.push({ TEXT: `AND TRSTATUS EQ '${filters.status.toUpperCase()}'` });
  }
  if (filters.category) {
    options.push({ TEXT: `AND TRFUNCTION EQ '${filters.category.toUpperCase()}'` });
  }

  const result = await client.call("RFC_READ_TABLE", {
    QUERY_TABLE: "E070",
    DELIMITER: "|",
    ROWCOUNT: max,
    OPTIONS: options,
    FIELDS: [{ FIELDNAME: "TRKORR" }],
  });

  const data = (result.DATA as Array<{ WA?: string }> | undefined) ?? [];
  return data
    .map((row) => (row.WA ?? "").split("|")[0]?.trim() ?? "")
    .filter(Boolean);
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
    description: String(result.DESCRIPTION ?? ""),
    category: String(result.CATEGORY ?? ""),
    client: String(result.CLIENT ?? ""),
    owner: String(result.OWNER ?? ""),
    status: String(result.STATUS ?? ""),
    retcode: String(result.RETCODE ?? "000"),
    message: String(result.MESSAGE ?? ""),
    objects: mapObjects(result.OBJECTS),
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
      const ids = await listRequestIds(client, filters);
      const requests: ChangeRequest[] = [];
      for (const id of ids) {
        try {
          requests.push(await readChangeRequest(client, id));
        } catch (err) {
          requests.push({
            request: id,
            description: "",
            category: "",
            client: "",
            owner: "",
            status: "",
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
    } finally {
      await client.close().catch(() => undefined);
    }
  }
}
