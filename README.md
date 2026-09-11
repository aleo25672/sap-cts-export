# CTS Extract

Three ways to pull SAP transport / change requests and get CSV. **Default path is bulk `E070` / `E07T` / `E071`** (fast). Optional **use FM** mode calls `CTS_API_READ_CHANGE_REQUEST` once per request.

| # | Option | Path | When to use |
|---|--------|------|-------------|
| **1** | **Pure ABAP report** | [`abap/src/zevo_cts_extract_requests.prog.abap`](./abap/src/zevo_cts_extract_requests.prog.abap) | Run inside SAP (SE38 / abapGit); GUI download or app-server file |
| **2** | **Node + RFC adapter** | [`node-app/`](./node-app/) with `CTS_ADAPTER=rfc` | Direct RFC from Node via `node-rfc` + NWRFC SDK (`RFC_READ_TABLE`) |
| **3** | **ABAP ICF + Node HTTP** | [`abap/src/zevo_cts_extract_icf.clas.abap`](./abap/src/zevo_cts_extract_icf.clas.abap) + `CTS_ADAPTER=http` | HTTPS to a custom SICF service |

ABAP objects are packaged for **[abapGit](https://docs.abapgit.org/)** (`.abapgit.xml` + `abap/src/*.prog.xml` / `*.clas.xml`). See [`abap/README.md`](./abap/README.md).

```text
1) SE38 report  →  E070/E07T/E071  (or CTS_API per TR)  →  CSV
2) Node RFC     →  RFC_READ_TABLE  (or CTS_API per TR)  →  CSV
3) Node HTTP    →  ICF ZEVO_CTS_EXTRACT_ICF → same bulk/FM paths → JSON/CSV
```

## Function module

`CTS_API_READ_CHANGE_REQUEST` (function group `CTS_API`, remote-enabled) — **optional slow path**:

| Direction | Parameter | Type |
|-----------|-----------|------|
| Importing | `REQUEST` | `CHAR20` |
| Exporting | `DESCRIPTION`, `CATEGORY`, `CLIENT`, `OWNER`, `STATUS`, `RETCODE`, `MESSAGE` | text / char |
| Tables | `OBJECTS` | `CTS_OBJ` |

The FM reads **one** request. Default extractors read CTS tables in bulk instead; check **Use CTS API (slow)** / `"useFm": true` / CLI `--use-fm` when you need the FM specifically.

---

## Option 1 — Pure ABAP

See [`abap/README.md`](./abap/README.md).

**abapGit (preferred):** online pull or offline ZIP into package `ZEVO_CTS`.  
**Manual:** paste [`abap/src/zevo_cts_extract_requests.prog.abap`](./abap/src/zevo_cts_extract_requests.prog.abap) into program `ZEVO_CTS_EXTRACT_REQUESTS`.

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

Requires NWRFC SDK, network to the app server, and an RFC user that can call `RFC_READ_TABLE` on `E070`/`E07T`/`E071` (and `CTS_API_READ_CHANGE_REQUEST` if you enable use-FM mode).

---

## Option 3 — Custom ABAP ICF + Node HTTP adapter

1. Install ABAP via abapGit (or paste the class), then wire SICF: [`abap/ICF.md`](./abap/ICF.md) / [`abap/src/zevo_cts_extract_icf.clas.abap`](./abap/src/zevo_cts_extract_icf.clas.abap)
2. Point Node at it:

```bash
cd node-app
CTS_ADAPTER=http
CTS_HTTP_URL=https://<host>:<port>/sap/bc/zevo_cts_extract?sap-client=100
CTS_HTTP_USER=...
CTS_HTTP_PASSWD=...
npm start
```

**Local demo without SAP:** the Node app also exposes a mock of that ICF contract at  
`http://127.0.0.1:43127/sap/bc/zevo_cts_extract` — set `CTS_HTTP_URL` to that URL with `CTS_ADAPTER=http`.

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
- `POST /sap/bc/zevo_cts_extract` — local ICF-shaped mock (for option 3 demos)

## CSV columns

```text
REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE
```
