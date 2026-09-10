#!/usr/bin/env node
import "dotenv/config";
import { writeFileSync } from "node:fs";
import { createAdapter } from "./adapters/index.js";
import { toCsv } from "./lib/csv.js";
import type { ExtractFilters } from "./lib/types.js";

function arg(name: string): string | undefined {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

function flag(name: string): boolean {
  return process.argv.includes(`--${name}`);
}

async function main() {
  const out = arg("out") || "cts_extract.csv";
  const filters: ExtractFilters = {
    requests: arg("requests")?.split(/[\s,;]+/).filter(Boolean),
    owner: arg("owner"),
    status: arg("status"),
    category: arg("category"),
    dateFrom: arg("from"),
    dateTo: arg("to"),
    max: arg("max") ? Number(arg("max")) : 500,
    includeHeaders: !flag("no-headers"),
    includeObjects: !flag("no-objects"),
  };

  const adapter = createAdapter();
  const result = await adapter.extract(filters);
  const csv = toCsv(result.requests, filters);
  writeFileSync(out, csv, "utf8");
  console.log(
    `Wrote ${out} (${result.ok} ok, ${result.failed} failed, adapter=${result.adapter})`,
  );
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
