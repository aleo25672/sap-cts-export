export type CtsObject = {
  pgmid: string;
  object: string;
  objName: string;
};

export type ChangeRequest = {
  request: string;
  description: string;
  category: string;
  client: string;
  owner: string;
  status: string;
  retcode: string;
  message: string;
  objects: CtsObject[];
};

export type ExtractFilters = {
  /** Explicit request IDs; when set, date/owner filters are ignored for listing */
  requests?: string[];
  owner?: string;
  status?: string;
  /** E070-TRFUNCTION: K / W / T … */
  category?: string;
  dateFrom?: string; // YYYY-MM-DD or YYYYMMDD
  dateTo?: string;
  max?: number;
  includeHeaders?: boolean;
  includeObjects?: boolean;
};

export type ExtractResult = {
  adapter: "mock" | "rfc";
  fetchedAt: string;
  requests: ChangeRequest[];
  ok: number;
  failed: number;
};

export interface CtsAdapter {
  readonly name: "mock" | "rfc";
  extract(filters: ExtractFilters): Promise<ExtractResult>;
}
