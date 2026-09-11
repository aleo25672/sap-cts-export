# CTS Extract

Three ways to pull SAP transport / change requests through **`CTS_API_READ_CHANGE_REQUEST`** and get CSV:

| # | Option | Path | When to use |
|---|--------|------|-------------|
| **1** | **Pure ABAP report** | [`abap/evo_cts_extract_requests.abap`](./abap/evo_cts_extract_requests.abap) | Run inside SAP (SE38); GUI download or app-server file |
| **2** | **Node + RFC adapter** | [`node-app/`](./node-app/) with `CTS_ADAPTER=rfc` | Direct RFC from Node via `node-rfc` + NWRFC SDK |
| **3** | **ABAP ICF + Node HTTP** | [`abap/evo_cts_extract_icf.clas.abap`](./abap/evo_cts_extract_icf.clas.abap) + `CTS_ADAPTER=http` | HTTPS to a custom SICF service that wraps the FM |

```text
1) SE38 report  →  CTS_API_READ_CHANGE_REQUEST  →  CSV
2) Node RFC     →  CTS_API_READ_CHANGE_REQUEST  →  CSV
3) Node HTTP    →  ICF EVO_CTS_EXTRACT_ICF  →  CTS_API_READ_CHANGE_REQUEST  →  JSON/CSV
```

## Function module

`CTS_API_READ_CHANGE_REQUEST` (function group `CTS_API`, remote-enabled):

| Direction | Parameter | Type |
|-----------|-----------|------|
| Importing | `REQUEST` | `CHAR20` |
| Exporting | `DESCRIPTION`, `CATEGORY`, `CLIENT`, `OWNER`, `STATUS`, `RETCODE`, `MESSAGE` | text / char |
| Tables | `OBJECTS` | `CTS_OBJ` |

The FM reads **one** request. All options resolve a list of IDs (from `E070` or an explicit list), then call the FM per ID.

---

## Option 1 — Pure ABAP

See [`abap/README.md`](./abap/README.md). Paste the report into `EVO_CTS_EXTRACT_REQUESTS` and activate.

---

## Option 2 — Node RFC adapter

```bash
cd node-app
cp .env.example .env
# CTS_ADAPTER=rfc + SAP_* connection vars
npm install
npm install node-rfc   # needs SAP NWRFC SDK on the machine
npm start
```

Requires NWRFC SDK, network to the app server, and an RFC user that can call the FM (and `RFC_READ_TABLE` on `E070` if you filter by date/owner).

---

## Option 3 — Custom ABAP ICF + Node HTTP adapter

1. Install the ICF handler: [`abap/ICF.md`](./abap/ICF.md) / [`abap/evo_cts_extract_icf.clas.abap`](./abap/evo_cts_extract_icf.clas.abap)
2. Point Node at it:

```bash
cd node-app
CTS_ADAPTER=http
CTS_HTTP_URL=https://<host>:<port>/sap/bc/evo_cts_extract?sap-client=100
CTS_HTTP_USER=...
CTS_HTTP_PASSWD=...
npm start
```

**Local demo without SAP:** the Node app also exposes a mock of that ICF contract at  
`http://127.0.0.1:43127/sap/bc/evo_cts_extract` — set `CTS_HTTP_URL` to that URL with `CTS_ADAPTER=http`.

---

## Node UI / CLI (options 2 & 3, plus mock)

```bash
cd node-app && npm install && npm start
```

App: [http://127.0.0.1:43127](http://127.0.0.1:43127)

```bash
npm run extract -- --requests S4HK900123,S4HK900124 --out transports.csv
```

### Adapters (`CTS_ADAPTER`)

| Value | Behaviour |
|-------|-----------|
| `mock` | Sample JSON (default) |
| `rfc` | `node-rfc` → FM |
| `http` | HTTPS → ICF handler → FM |

### API

- `GET /api/health`
- `POST /api/extract` — JSON preview
- `POST /api/extract.csv` — CSV download
- `POST /sap/bc/evo_cts_extract` — local ICF-shaped mock (for option 3 demos)

## CSV columns

```text
REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE
```
