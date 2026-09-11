import type {
  ChangeRequest,
  CtsAdapter,
  CtsObject,
  ExtractFilters,
  ExtractResult,
} from "../lib/types.js";

type IcfObject = {
  pgmid?: string;
  object?: string;
  objName?: string;
  obj_name?: string;
};

type IcfRequest = {
  request?: string;
  description?: string;
  category?: string;
  client?: string;
  owner?: string;
  status?: string;
  retcode?: string;
  message?: string;
  objects?: IcfObject[];
};

type IcfResponse = {
  adapter?: string;
  fetchedAt?: string;
  fetched_at?: string;
  ok?: number;
  failed?: number;
  requests?: IcfRequest[];
  error?: string;
};

function mapObject(raw: IcfObject): CtsObject {
  return {
    pgmid: String(raw.pgmid ?? ""),
    object: String(raw.object ?? ""),
    objName: String(raw.objName ?? raw.obj_name ?? ""),
  };
}

function mapRequest(raw: IcfRequest): ChangeRequest {
  return {
    request: String(raw.request ?? ""),
    description: String(raw.description ?? ""),
    category: String(raw.category ?? ""),
    client: String(raw.client ?? ""),
    owner: String(raw.owner ?? ""),
    status: String(raw.status ?? ""),
    retcode: String(raw.retcode ?? "000"),
    message: String(raw.message ?? ""),
    objects: (raw.objects ?? []).map(mapObject),
  };
}

function authHeader(): Record<string, string> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  if (process.env.CTS_HTTP_TOKEN) {
    headers.Authorization = `Bearer ${process.env.CTS_HTTP_TOKEN}`;
    return headers;
  }

  const user = process.env.CTS_HTTP_USER;
  const pass = process.env.CTS_HTTP_PASSWD ?? process.env.CTS_HTTP_PASSWORD ?? "";
  if (user) {
    headers.Authorization = `Basic ${Buffer.from(`${user}:${pass}`).toString("base64")}`;
  }
  return headers;
}

function endpointUrl(): string {
  const base = (process.env.CTS_HTTP_URL || "").trim().replace(/\/$/, "");
  if (!base) {
    throw new Error(
      "CTS_HTTP_URL is required when CTS_ADAPTER=http (e.g. https://host:44300/sap/bc/zevo_cts_extract?sap-client=100).",
    );
  }
  return base;
}

/** Calls the custom ABAP ICF handler (ZEVO_CTS_EXTRACT_ICF). */
export class HttpAdapter implements CtsAdapter {
  readonly name = "http" as const;

  async extract(filters: ExtractFilters): Promise<ExtractResult> {
    const url = endpointUrl();
    const body = {
      requests: filters.requests ?? [],
      owner: filters.owner ?? "",
      status: filters.status ?? "",
      category: filters.category ?? "",
      dateFrom: filters.dateFrom ?? "",
      dateTo: filters.dateTo ?? "",
      max: filters.max && filters.max > 0 ? filters.max : 500,
      includeObjects: filters.includeObjects !== false,
      useFm: filters.useFm === true,
      format: "json",
    };

    const res = await fetch(url, {
      method: "POST",
      headers: authHeader(),
      body: JSON.stringify(body),
    });

    const text = await res.text();
    let data: IcfResponse;
    try {
      data = JSON.parse(text) as IcfResponse;
    } catch {
      throw new Error(
        `ICF response was not JSON (HTTP ${res.status}): ${text.slice(0, 240)}`,
      );
    }

    if (!res.ok) {
      throw new Error(data.error || `ICF HTTP ${res.status}: ${text.slice(0, 240)}`);
    }

    const requests = (data.requests ?? []).map(mapRequest);
    const failed =
      data.failed ??
      requests.filter((r) => r.retcode && r.retcode !== "000").length;
    const ok = data.ok ?? requests.length - failed;

    return {
      adapter: "http",
      fetchedAt: data.fetchedAt ?? data.fetched_at ?? new Date().toISOString(),
      requests,
      ok,
      failed,
    };
  }
}
