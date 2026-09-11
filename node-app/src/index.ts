import "dotenv/config";
import express from "express";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createAdapter, MockAdapter } from "./adapters/index.js";
import { toCsv } from "./lib/csv.js";
import type { ExtractFilters } from "./lib/types.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 43127);
const HOST = process.env.HOST || "0.0.0.0";

const app = express();
app.use(express.json({ limit: "1mb" }));
app.use(express.static(join(__dirname, "public")));

function parseBody(body: Record<string, unknown>): ExtractFilters {
  const requestsRaw = String(body.requests ?? "").trim();
  const requests = requestsRaw
    ? requestsRaw
        .split(/[\s,;]+/)
        .map((r) => r.trim())
        .filter(Boolean)
    : Array.isArray(body.requests)
      ? (body.requests as unknown[]).map((r) => String(r).trim()).filter(Boolean)
      : undefined;

  return {
    requests: requests?.length ? requests : undefined,
    owner: body.owner ? String(body.owner).trim() : undefined,
    status: body.status ? String(body.status).trim() : undefined,
    category: body.category ? String(body.category).trim() : undefined,
    dateFrom: body.dateFrom ? String(body.dateFrom).trim() : undefined,
    dateTo: body.dateTo ? String(body.dateTo).trim() : undefined,
    max: body.max != null && body.max !== "" ? Number(body.max) : 500,
    includeHeaders: body.includeHeaders !== false && body.includeHeaders !== "false",
    includeObjects: body.includeObjects !== false && body.includeObjects !== "false",
  };
}

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    adapter: process.env.CTS_ADAPTER || "mock",
    fm: "CTS_API_READ_CHANGE_REQUEST",
    options: [
      "1: pure ABAP report",
      "2: Node RFC adapter",
      "3: ABAP ICF + Node HTTP adapter",
    ],
  });
});

/**
 * Local stand-in for /sap/bc/evo_cts_extract so CTS_ADAPTER=http can be demoed
 * without a live SAP system. Same JSON contract as EVO_CTS_EXTRACT_ICF.
 */
app.post("/sap/bc/evo_cts_extract", async (req, res) => {
  try {
    const filters = parseBody(req.body ?? {});
    const result = await new MockAdapter().extract(filters);
    res.json({
      adapter: "icf",
      fetchedAt: result.fetchedAt,
      ok: result.ok,
      failed: result.failed,
      requests: result.requests,
    });
  } catch (err) {
    res.status(500).json({
      error: err instanceof Error ? err.message : String(err),
    });
  }
});

app.get("/sap/bc/evo_cts_extract", async (req, res) => {
  try {
    const q = req.query as Record<string, unknown>;
    const filters = parseBody({
      requests: q.request ?? q.requests ?? "",
      owner: q.owner ?? "",
      status: q.status ?? "",
      category: q.category ?? "",
      dateFrom: q.dateFrom ?? "",
      dateTo: q.dateTo ?? "",
      max: q.max ?? 500,
    });
    const result = await new MockAdapter().extract(filters);
    if (String(q.format || "json").toLowerCase() === "csv") {
      const csv = toCsv(result.requests, { ...filters, includeObjects: true });
      res.setHeader("Content-Type", "text/csv; charset=utf-8");
      res.send(csv);
      return;
    }
    res.json({
      adapter: "icf",
      fetchedAt: result.fetchedAt,
      ok: result.ok,
      failed: result.failed,
      requests: result.requests,
    });
  } catch (err) {
    res.status(500).json({
      error: err instanceof Error ? err.message : String(err),
    });
  }
});

app.post("/api/extract", async (req, res) => {
  try {
    const filters = parseBody(req.body ?? {});
    const adapter = createAdapter();
    const result = await adapter.extract(filters);
    res.json(result);
  } catch (err) {
    res.status(500).json({
      error: err instanceof Error ? err.message : String(err),
    });
  }
});

app.post("/api/extract.csv", async (req, res) => {
  try {
    const filters = parseBody(req.body ?? {});
    const adapter = createAdapter();
    const result = await adapter.extract(filters);
    const csv = toCsv(result.requests, filters);
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="cts_extract_${stamp}.csv"`,
    );
    res.send(csv);
  } catch (err) {
    res.status(500).json({
      error: err instanceof Error ? err.message : String(err),
    });
  }
});

app.listen(PORT, HOST, () => {
  console.log(`CTS Extract listening on http://${HOST}:${PORT}`);
  console.log(`Adapter: ${process.env.CTS_ADAPTER || "mock"}`);
});
