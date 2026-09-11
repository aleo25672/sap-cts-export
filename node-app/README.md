# CTS Extract — Node.js app

Web UI + CLI for options **2 (RFC)** and **3 (HTTP/ICF)**, plus a **mock** adapter for local demos.

## Quick start (mock)

```bash
cp .env.example .env
npm install
npm start
```

UI: http://127.0.0.1:43127

## Adapters

| `CTS_ADAPTER` | Needs | Calls |
|---------------|-------|-------|
| `mock` | nothing | sample JSON |
| `rfc` | NWRFC SDK + `node-rfc` | Default: `RFC_READ_TABLE` on `E070`/`E07T`/`E071`; optional `CTS_API_READ_CHANGE_REQUEST` per TR (`useFm`) |
| `http` | `CTS_HTTP_URL` (+ Basic/Bearer) | ABAP ICF `ZEVO_CTS_EXTRACT_ICF` (same bulk/FM behavior server-side) |

Pass `"useFm": true` in the UI/API, or CLI `--use-fm`, to force the slow FM path on RFC/HTTP.

### RFC

```bash
CTS_ADAPTER=rfc
SAP_ASHOST=...
SAP_SYSNR=00
SAP_CLIENT=100
SAP_USER=...
SAP_PASSWD=...
npm install node-rfc
```

### HTTP / ICF

Point at the real SICF service (see [`../abap/ICF.md`](../abap/ICF.md)):

```bash
CTS_ADAPTER=http
CTS_HTTP_URL=https://sap.example.com:44300/sap/bc/zevo_cts_extract?sap-client=100
CTS_HTTP_USER=...
CTS_HTTP_PASSWD=...
```

Or demo the ICF contract locally (same Node process mocks `/sap/bc/zevo_cts_extract`):

```bash
CTS_ADAPTER=http
CTS_HTTP_URL=http://127.0.0.1:43127/sap/bc/zevo_cts_extract
```

## Scripts

| Script | Purpose |
|--------|---------|
| `npm start` | HTTP server + UI |
| `npm run dev` | Watch mode |
| `npm run extract -- …` | CLI CSV |
| `npm run build` | Typecheck |
