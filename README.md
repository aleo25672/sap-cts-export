# CTS Extract

Two ways to pull SAP transport / change requests through **`CTS_API_READ_CHANGE_REQUEST`** and save them as CSV:

| Option | Path | When to use |
|--------|------|-------------|
| **ABAP report** | [`abap/`](./abap/) | Run inside the SAP system (SE38), GUI download or app-server file |
| **Node.js app** | [`node-app/`](./node-app/) | Extract over RFC from a workstation or server; browser UI + CLI |

Both produce the same CSV shapes (request headers and/or object lines).

## Function module

`CTS_API_READ_CHANGE_REQUEST` (function group `CTS_API`, remote-enabled):

| Direction | Parameter | Type |
|-----------|-----------|------|
| Importing | `REQUEST` | `CHAR20` |
| Exporting | `DESCRIPTION`, `CATEGORY`, `CLIENT`, `OWNER`, `STATUS`, `RETCODE`, `MESSAGE` | text / char |
| Tables | `OBJECTS` | `CTS_OBJ` |

The FM reads **one** request. Both extractors select a list of request IDs (from `E070` or an explicit list), then call the FM per ID.

## Option A — ABAP

See [`abap/README.md`](./abap/README.md). Paste [`abap/z_cts_extract_requests.abap`](./abap/z_cts_extract_requests.abap) into program `Z_CTS_EXTRACT_REQUESTS` and activate.

## Option B — Node.js

```bash
cd node-app
cp .env.example .env
npm install
npm start
```

Open the UI (default [http://127.0.0.1:43127](http://127.0.0.1:43127)).

### Adapters

- **`CTS_ADAPTER=mock`** (default) — uses [`node-app/sample-data/mock-requests.json`](./node-app/sample-data/mock-requests.json). No SAP system required.
- **`CTS_ADAPTER=rfc`** — connects with [`node-rfc`](https://www.npmjs.com/package/node-rfc) and the SAP NetWeaver RFC SDK. Lists IDs via `RFC_READ_TABLE` on `E070` (or uses IDs you paste), then calls `CTS_API_READ_CHANGE_REQUEST`.

RFC env vars (see `.env.example`):

```bash
CTS_ADAPTER=rfc
SAP_ASHOST=...
SAP_SYSNR=00
SAP_CLIENT=100
SAP_USER=...
SAP_PASSWD=...
SAP_LANG=EN
```

### CLI

```bash
npm run extract -- --requests S4HK900123,S4HK900124 --out transports.csv
npm run extract -- --from 2026-03-01 --to 2026-04-30 --owner DEVELOPER1
```

### API

- `GET /api/health`
- `POST /api/extract` — JSON preview
- `POST /api/extract.csv` — CSV download

## CSV columns

**Object rows**

```text
REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE
```

**Header-only rows**

```text
REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,RETCODE,MESSAGE
```
