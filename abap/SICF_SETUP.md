# Generic SICF / ICF setup tool

SICF nodes are **not** shipped by abapGit. This repo includes a reusable utility so any project can create, update, activate, or deactivate HTTP services without clicking through transaction SICF.

| Object | Name | Role |
|--------|------|------|
| Class | `ZEVO_CL_SICF_SETUP` | API (callable from any report / post-install) |
| Report | `ZEVO_SICF_SETUP` | Interactive / batch UI |

## Why a generic tool?

Other projects need the same steps: parent path → service name → handler class → activate. Hard-coding one CTS path does not scale. This utility takes **URL + handler(s)** as parameters (or a batch list) and works for any HTTP extension class.

## Quick start (this CTS project)

1. abapGit pull / activate `ZEVO_CL_SICF_SETUP` and `ZEVO_SICF_SETUP`.
2. SE38 → `ZEVO_SICF_SETUP`.
3. Defaults already point at this project:
   - URL: `/sap/bc/zevo_cts_extract`
   - Handler: `ZEVO_CTS_EXTRACT_ICF`
4. Action **Ensure (create/update)**, optional **Dry-run** first.
5. Execute.

Still configure **logon** (Basic Auth / service user) once in SICF if the API left anonymous access unset — credentials stay system-specific.

## Use from another project

### A) Selection screen (single)

| Field | Example |
|-------|---------|
| ICF URL path | `/sap/bc/zmy_api` |
| Handler class | `ZCL_MY_HTTP_HANDLER` |
| Description | My API |
| Activate after save | X |

Parent `/sap/bc` must already exist (standard).

### B) Batch mode (several services / projects)

Switch to **Batch** and enter one definition per line:

```text
# URL;HANDLER[;HANDLER…][;description]
/sap/bc/zevo_cts_extract;ZEVO_CTS_EXTRACT_ICF;CTS Extract API
/sap/bc/zmy_api;ZCL_MY_HTTP_HANDLER;My project API
/sap/bc/zbilling;ZCL_BILL_HANDLER;ZCL_BILL_AUTH;Billing API
```

### C) Call the class from your own post-install report

```abap
DATA ls_def TYPE zevo_cl_sicf_setup=>ty_service_def.
DATA ls_h   TYPE zevo_cl_sicf_setup=>ty_handler.
DATA ls_res TYPE zevo_cl_sicf_setup=>ty_result.

ls_def-url         = '/sap/bc/zmy_api'.
ls_def-description = 'My project API'.
ls_def-activate    = abap_true.
ls_h-classname     = 'ZCL_MY_HTTP_HANDLER'.
APPEND ls_h TO ls_def-handlers.

ls_res = zevo_cl_sicf_setup=>ensure( is_def = ls_def ).
IF ls_res-ok = abap_false.
  MESSAGE ls_res-message TYPE 'E'.
ENDIF.
```

Other API methods: `activate`, `deactivate`, `get_status`, `parse_batch`, `normalize_url`.

## Actions

| Action | Effect |
|--------|--------|
| Ensure | Create under parent if missing; set handlers + description; optional activate |
| Activate only | Activate existing node |
| Deactivate only | Deactivate existing node |
| Show status | Exists / active / handlers / description |
| Dry-run | Print intended changes; write nothing |

## Prerequisites

- Handler class exists and implements `IF_HTTP_EXTENSION` (or your release’s HTTP handler IF).
- Parent path exists (usually `/sap/bc`).
- User can maintain ICF (e.g. `S_ICF_ADM` / project-specific roles).
- After setup: assign suitable logon procedure and authorizations for callers.

## Landscape tip

Run once in DEV, capture the ICFSERV change on a transport if your process allows, then import. Or re-run `ZEVO_SICF_SETUP` (same parameters) in Q/P after each import — the tool is idempotent.

## Limits

- Does not create virtual hosts or SSL endpoints.
- Does not set anonymous users / ICF aliases (do that in SICF when needed).
- `CL_ICF_TREE` method names vary by BASIS; the class tries common names and returns a clear error if your release differs — open an issue / adjust the dynamic calls in `ZEVO_CL_SICF_SETUP`.
