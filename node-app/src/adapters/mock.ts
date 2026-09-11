import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type {
  ChangeRequest,
  CtsAdapter,
  ExtractFilters,
  ExtractResult,
} from "../lib/types.js";

type MockRecord = ChangeRequest;

const __dirname = dirname(fileURLToPath(import.meta.url));
const samplePath = join(__dirname, "../../sample-data/mock-requests.json");

function toYmd(raw?: string): string | undefined {
  if (!raw) return undefined;
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 8) return digits;
  return undefined;
}

function matches(record: MockRecord, filters: ExtractFilters): boolean {
  if (filters.requests?.length) {
    const set = new Set(filters.requests.map((r) => r.trim().toUpperCase()));
    return set.has(record.request.toUpperCase());
  }
  if (filters.owner && record.owner.toUpperCase() !== filters.owner.toUpperCase()) {
    return false;
  }
  if (filters.status && record.status.toUpperCase() !== filters.status.toUpperCase()) {
    return false;
  }
  if (filters.category && record.category.toUpperCase() !== filters.category.toUpperCase()) {
    return false;
  }
  const from = toYmd(filters.dateFrom);
  const to = toYmd(filters.dateTo);
  if (from && record.as4date < from) return false;
  if (to && record.as4date > to) return false;
  return true;
}

export class MockAdapter implements CtsAdapter {
  readonly name = "mock" as const;

  async extract(filters: ExtractFilters): Promise<ExtractResult> {
    const catalog = JSON.parse(readFileSync(samplePath, "utf8")) as MockRecord[];
    const max = filters.max && filters.max > 0 ? filters.max : 500;
    const selected = catalog.filter((r) => matches(r, filters)).slice(0, max);

    const requests: ChangeRequest[] = selected.map((row) => ({
      ...row,
      as4date: row.as4date ?? "",
      as4time: row.as4time ?? "",
      tarsystem: row.tarsystem ?? "",
    }));

    const failed = requests.filter((r) => r.retcode && r.retcode !== "000").length;
    const ok = requests.length - failed;

    return {
      adapter: "mock",
      fetchedAt: new Date().toISOString(),
      requests,
      ok,
      failed,
    };
  }
}
