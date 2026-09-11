# ABAP extractors

## 1. Pure ABAP report (option 1)

Executable report that selects transport headers from `E070`, calls **`CTS_API_READ_CHANGE_REQUEST`** for each request, and writes a CSV (GUI download or app-server file).

### Install

1. SE38 / ADT: create program `Z_CTS_EXTRACT_REQUESTS` (Executable).
2. Paste [`z_cts_extract_requests.abap`](./z_cts_extract_requests.abap) and activate.
3. In SE11, open **`CTS_OBJ`** and confirm component names (`PGMID`, `OBJECT`, `OBJ_NAME` or `OBJNAME`). Adjust `FORM map_cts_object` if needed.

### Selection parameters

| Parameter | Meaning |
|-----------|---------|
| `P_TRKORR` | Single transport (skips date/owner filters) |
| `P_USER` | Owner (`E070-AS4USER`) |
| `P_FROM` / `P_TO` | Creation date range |
| `P_STATUS` | `E070-TRSTATUS` |
| `P_FUNCT` | `E070-TRFUNCTION` (`K` / `W` / `T`) |
| `P_GUI` / `P_FILE` | GUI download vs dataset |
| `P_PATH` | App-server path when `P_FILE` is set |
| `P_HDR` / `P_OBJ` | Header and/or object CSV rows |
| `P_MAX` | Max requests (default 500) |

---

## 3. ICF HTTP handler (option 3)

Class **`ZCL_CTS_EXTRACT_ICF`** — see [`ICF.md`](./ICF.md) and [`zcl_cts_extract_icf.clas.abap`](./zcl_cts_extract_icf.clas.abap).

Same FM underneath; exposes JSON/CSV over HTTPS for the Node `http` adapter.

---

## Authorizations

Caller needs CTS display authority (typically `S_TRANSPRT`). ICF also needs service execution rights for the technical user.
