# CTS Extract — Node.js app

Web UI + CLI that call `CTS_API_READ_CHANGE_REQUEST` and export CSV.

## Quick start (mock, no SAP)

```bash
cp .env.example .env
npm install
npm start
```

App: http://127.0.0.1:43127

## RFC mode

1. Install the [SAP NWRFC SDK](https://support.sap.com/en/product/connectors/nwrfcsdk.html) and set `SAPNWRFC_HOME` / library path per SAP docs.
2. `npm install node-rfc`
3. Set in `.env`:

```bash
CTS_ADAPTER=rfc
SAP_ASHOST=...
SAP_SYSNR=00
SAP_CLIENT=100
SAP_USER=...
SAP_PASSWD=...
```

Or use `SAP_DEST=...` with `sapnwrfc.ini`.

## Scripts

| Script | Purpose |
|--------|---------|
| `npm start` | HTTP server + UI |
| `npm run dev` | Same with file watch |
| `npm run extract -- …` | CLI CSV write |
| `npm run build` | Typecheck |
