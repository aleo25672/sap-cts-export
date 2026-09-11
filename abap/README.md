# ABAP (abapGit)

This folder is an **abapGit** project (see `.abapgit.xml` at the repo root).  
You do **not** need a single hand-made “import.xml” — abapGit uses one `.xml` metadata file **per object**, next to the `.abap` source.

## Layout

```text
.abapgit.xml                          ← repo root (abapGit config)
abap/src/
  package.devc.xml                    ← package metadata
  zevo_cts_extract_requests.prog.abap
  zevo_cts_extract_requests.prog.xml
  zevo_cts_extract_icf.clas.abap
  zevo_cts_extract_icf.clas.xml
```

| Object | Name |
|--------|------|
| Package (suggested) | `ZEVO_CTS` |
| Report | `ZEVO_CTS_EXTRACT_REQUESTS` |
| ICF class | `ZEVO_CTS_EXTRACT_ICF` |

## Import with abapGit (recommended)

### Online (GitHub / Origin URL)

1. Install [abapGit](https://docs.abapgit.org/) in the SAP system.
2. **New online** → paste the Git URL of this repo.
3. Create/assign package **`ZEVO_CTS`** (or another `Z*` package).
4. **Pull** → activate.
5. Create the SICF node manually (see [`ICF.md`](./ICF.md)) — SICF is not serialized here.

### Offline (ZIP)

1. On GitHub: **Code → Download ZIP** (or `git archive`).
2. In abapGit: **New offline** → upload the ZIP.
3. Pull / install into package `ZEVO_CTS` → activate.
4. Create SICF as in [`ICF.md`](./ICF.md).

## Performance

By default the report uses **bulk table reads** (`E070` / `E07T` / `E071`) — typically seconds even for hundreds of transports.

Optional checkbox **Use CTS API (slow)** calls `CTS_API_READ_CHANGE_REQUEST` once per request (API-faithful, much slower). Use only when you need the FM path specifically.

Also:
- Selects only required columns (not `SELECT *`)
- Avoids `OR` on empty filters so date/owner indexes stay usable
- Caps volume with **Max requests**

## After import

- Activate `ZEVO_CTS_EXTRACT_REQUESTS` and `ZEVO_CTS_EXTRACT_ICF`.
- Confirm `CTS_OBJ` field names in SE11 if object mapping is empty.
- ICF class needs `/UI2/CL_JSON`.
- Wire SICF `/sap/bc/zevo_cts_extract` → handler `ZEVO_CTS_EXTRACT_ICF`.
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
