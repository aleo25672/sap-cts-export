# ABAP ICF handler — `ZEVO_CTS_EXTRACT_ICF`

Exposes `CTS_API_READ_CHANGE_REQUEST` over **HTTP** so clients (including the Node `http` adapter) do not need RFC.

## Install

1. Create class **`ZEVO_CTS_EXTRACT_ICF`** (public, final) in SE24 / ADT and paste [`zevo_cts_extract_icf.clas.abap`](./zevo_cts_extract_icf.clas.abap).
2. Activate (requires **`/UI2/CL_JSON`**).
3. **SICF** → `default_host` → `sap` → `bc` → create service **`zevo_cts_extract`**.
4. Handler List → `ZEVO_CTS_EXTRACT_ICF`.
5. Configure logon (Basic Auth recommended for machine users).
6. Activate the service.

URL shape:

```text
https://<host>:<icm-port>/sap/bc/zevo_cts_extract?sap-client=100
```

## API

### POST JSON

```http
POST /sap/bc/zevo_cts_extract
Content-Type: application/json
Authorization: Basic …

{
  "requests": ["S4HK900123", "S4HK900124"],
  "owner": "",
  "status": "",
  "category": "",
  "dateFrom": "20260301",
  "dateTo": "20260430",
  "max": 500,
  "format": "json"
}
```

If `requests` is empty, headers are selected from `E070` using the filters (same idea as the SE38 report).

### GET

```http
GET /sap/bc/zevo_cts_extract?request=S4HK900123&format=json
GET /sap/bc/zevo_cts_extract?dateFrom=20260301&dateTo=20260430&owner=DEVELOPER1&format=csv
```

### Response (`format=json`)

CamelCase JSON compatible with the Node app:

```json
{
  "adapter": "icf",
  "fetchedAt": "20260910T235959",
  "ok": 2,
  "failed": 0,
  "requests": [
    {
      "request": "S4HK900123",
      "description": "…",
      "category": "K",
      "client": "100",
      "owner": "DEVELOPER1",
      "status": "R",
      "retcode": "000",
      "message": "",
      "objects": [
        { "pgmid": "R3TR", "object": "CLAS", "objName": "ZCL_PRICING_HELPER" }
      ]
    }
  ]
}
```

### Response (`format=csv`)

Same columns as the pure ABAP report / Node CSV download.

## Authorizations

- ICF service execution for the service user
- CTS display (`S_TRANSPRT` etc.)
- `E070` read for filter-based listing
