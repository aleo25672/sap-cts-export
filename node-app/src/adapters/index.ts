import type { CtsAdapter } from "../lib/types.js";
import { HttpAdapter } from "./http.js";
import { MockAdapter } from "./mock.js";
import { RfcAdapter } from "./rfc.js";

export function createAdapter(name = process.env.CTS_ADAPTER || "mock"): CtsAdapter {
  const normalized = name.toLowerCase();
  if (normalized === "rfc") return new RfcAdapter();
  if (normalized === "http") return new HttpAdapter();
  if (normalized === "mock") return new MockAdapter();
  throw new Error(`Unknown CTS_ADAPTER="${name}". Use mock, rfc, or http.`);
}

export { HttpAdapter, MockAdapter, RfcAdapter };
