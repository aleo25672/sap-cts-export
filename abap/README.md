# ABAP extractor — `Z_CTS_EXTRACT_REQUESTS`

Executable report that selects transport headers from `E070`, calls **`CTS_API_READ_CHANGE_REQUEST`** for each request, and writes a CSV (GUI download or app-server file).

## Install

1. In SE38 or ADT, create program `Z_CTS_EXTRACT_REQUESTS` (Executable).
2. Paste [`z_cts_extract_requests.abap`](./z_cts_extract_requests.abap) and activate.
3. In SE11, open structure **`CTS_OBJ`** and confirm component names (`PGMID`, `OBJECT`, `OBJ_NAME` or `OBJNAME`). Adjust `FORM map_cts_object` if needed.

## Selection parameters

| Parameter | Meaning |
|-----------|---------|
| `P_TRKORR` | Single transport (skips date/owner filters) |
| `P_USER` | Owner (`E070-AS4USER`) |
| `P_FROM` / `P_TO` | Creation date range |
| `P_STATUS` | `E070-TRSTATUS` (e.g. `D` modifiable, `R` released) |
| `P_FUNCT` | `E070-TRFUNCTION` (`K` workbench, `W` customizing, `T` ToC) |
| `P_GUI` / `P_FILE` | Download via SAP GUI vs write dataset |
| `P_PATH` | App-server path when `P_FILE` is set |
| `P_HDR` / `P_OBJ` | Include header rows and/or object rows |
| `P_MAX` | Max requests (default 500) |

## CSV layouts

**Object mode** (`P_OBJ`):

```text
REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE
```

**Header-only mode** (`P_HDR` without objects):

```text
REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,RETCODE,MESSAGE
```

## Authorizations

Caller needs CTS display authority (typically `S_TRANSPRT`) and, for app-server write, dataset authority for `P_PATH`.
