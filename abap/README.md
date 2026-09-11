# ABAP (abapGit) — CTS Extract

This folder is the **CTS Extract** abapGit project (see `.abapgit.xml` at the repo root).  
SICF setup lives in a **separate** project: [`../sicf-setup/`](../sicf-setup/) (own `.abapgit.xml`, intended as its own Git remote).

## Layout

```text
.abapgit.xml                          ← repo root (CTS abapGit config; ignores /sicf-setup)
abap/src/
  package.devc.xml
  zevo_cts_extract_requests.prog.abap
  zevo_cts_extract_requests.prog.xml
  zevo_cts_extract_icf.clas.abap
  zevo_cts_extract_icf.clas.xml
sicf-setup/                           ← separate abapGit project (generic SICF tool)
  .abapgit.xml
  src/…
```

| Object | Name |
|--------|------|
| Package (suggested) | `ZEVO_CTS` |
| Report | `ZEVO_CTS_EXTRACT_REQUESTS` |
| ICF class | `ZEVO_CTS_EXTRACT_ICF` |

## Import with abapGit (recommended)

### Online (GitHub / Origin URL)

1. Install [abapGit](https://docs.abapgit.org/) in the SAP system.
2. **New online** → paste the Git URL of **this** (CTS) repo.
3. Create/assign package **`ZEVO_CTS`** (or another `Z*` package).
4. **Pull** → activate.
5. Install SICF tooling from the **[`sicf-setup`](../sicf-setup/)** repo (separate abapGit pull into `ZEVO_SICF`), then run **`ZEVO_SICF_SETUP`** — see [`../sicf-setup/README.md`](../sicf-setup/README.md) and [`ICF.md`](./ICF.md).

### Offline (ZIP)

1. On GitHub: **Code → Download ZIP** (or `git archive`).
2. In abapGit: **New offline** → upload the ZIP.
3. Pull / install into package `ZEVO_CTS` → activate.
4. Pull **`sicf-setup`** separately (or unzip that folder as its own offline repo), then create SICF as in [`ICF.md`](./ICF.md).

## Performance

By default the **report** and **ICF class** use **bulk table reads** (`E070` / `E07T` / `E071`) — typically seconds even for hundreds of transports.

Optional **Use CTS API (slow)** / JSON `"useFm": true` calls `CTS_API_READ_CHANGE_REQUEST` once per request (API-faithful, much slower). Use only when you need the FM path specifically.

Also:
- Selects only required columns (not `SELECT *`)
- Avoids `OR` on empty filters so date/owner indexes stay usable
- Caps volume with **Max requests**

The Node **RFC** and **HTTP** adapters mirror the same default vs. use-FM switch.

## After import

- Activate `ZEVO_CTS_EXTRACT_REQUESTS` and `ZEVO_CTS_EXTRACT_ICF`.
- Confirm `CTS_OBJ` field names in SE11 if object mapping is empty.
- ICF class needs `/UI2/CL_JSON`.
- Wire SICF via the **separate** [`sicf-setup`](../sicf-setup/) tool: URL `/sap/bc/zevo_cts_extract`, handler `ZEVO_CTS_EXTRACT_ICF` (see example batch in that repo).
- For app-server CSV output, maintain logical file **`ZEVO_CTS_EXTRACT`** in transaction **FILE** (see below).

## Logical file (transaction FILE)

When **Write app-server file** is selected, the report resolves the path with `FILE_GET_NAME`:

1. Transaction **FILE** → Logical file name definition.
2. Create logical file **`ZEVO_CTS_EXTRACT`** (or change `P_LFILE` on the selection screen).
3. Assign a logical path / physical path suitable for your OS, e.g.  
   `<P=DIR_HOME>/cts_extract_<PARAM_1>_<PARAM_2>.csv`  
   (`PARAM_1` = date, `PARAM_2` = time, passed by the report).
4. Optional: fill **Physical path** on the selection screen to bypass FILE and write to that path directly.

## Manual paste (fallback)

If abapGit is not available, create the program/class in SE38/SE24 and paste the `.abap` sources from `abap/src/`.

Radio/checkbox labels are set in `INITIALIZATION` in the report source, so they appear even without importing the text pool. For typed fields (`P_TRKORR`, dates, …), either:

1. Prefer **abapGit pull** (imports `*.prog.xml` selection texts), or  
2. In SE38 → **Goto → Text elements → Selection texts**, enter the labels, save, activate.
