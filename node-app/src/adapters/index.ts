import type { CtsAdapter } from "../lib/types.js";
import { MockAdapter } from "./mock.js";
import { RfcAdapter } from "./rfc.js";

export function createAdapter(name = process.env.CTS_ADAPTER || "mock"): CtsAdapter {
  const normalized = name.toLowerCase();
  if (normalized === "rfc") return new RfcAdapter();
  if (normalized === "mock") return new MockAdapter();
  throw new Error(`Unknown CTS_ADAPTER="${name}". Use mock or rfc.`);
}

export { MockAdapter, RfcAdapter };
