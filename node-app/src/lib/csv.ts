import type { ChangeRequest, ExtractFilters } from "./types.js";

function escapeCell(value: string): string {
  if (/[",\r\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function normalizeFlags(filters: ExtractFilters) {
  const includeHeaders = filters.includeHeaders !== false;
  const includeObjects = filters.includeObjects !== false;
  return { includeHeaders, includeObjects };
}

function headerCells(req: ChangeRequest): string[] {
  return [
    req.request,
    req.description,
    req.category,
    req.client,
    req.owner,
    req.status,
    req.as4date,
    req.as4time,
    req.tarsystem,
  ];
}

/** Source table / API for each CSV column (bulk tables vs useFm). */
function sourceHeaderRow(includeObjects: boolean, useFm: boolean): string {
  if (useFm) {
    return includeObjects
      ? "E070,CTS_API,CTS_API,CTS_API,CTS_API,CTS_API,E070,E070,E070,CTS_OBJ,CTS_OBJ,CTS_OBJ,CTS_API,CTS_API"
      : "E070,CTS_API,CTS_API,CTS_API,CTS_API,CTS_API,E070,E070,E070,CTS_API,CTS_API";
  }
  // Bulk E070/E07T/E071 — CLIENT/RETCODE/MESSAGE not filled from tables
  return includeObjects
    ? "E070,E07T,E070,,E070,E070,E070,E070,E070,E071,E071,E071,,"
    : "E070,E07T,E070,,E070,E070,E070,E070,E070,,";
}

/** Flatten extract results into CSV (header and/or object rows). */
export function toCsv(
  requests: ChangeRequest[],
  filters: ExtractFilters = {},
): string {
  const { includeHeaders, includeObjects } = normalizeFlags(filters);
  const includeSourceRow = filters.includeSourceRow !== false;
  const useFm = filters.useFm === true;
  const lines: string[] = [];

  if (includeObjects) {
    lines.push(
      "REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,AS4DATE,AS4TIME,TARSYSTEM,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE",
    );
    if (includeSourceRow) {
      lines.push(sourceHeaderRow(true, useFm));
    }
    for (const req of requests) {
      if (req.objects.length === 0) {
        if (includeHeaders || req.retcode) {
          lines.push(
            [...headerCells(req), "", "", "", req.retcode, req.message]
              .map((c) => escapeCell(String(c ?? "")))
              .join(","),
          );
        }
        continue;
      }
      for (const obj of req.objects) {
        lines.push(
          [
            ...headerCells(req),
            obj.pgmid,
            obj.object,
            obj.objName,
            req.retcode,
            req.message,
          ]
            .map((c) => escapeCell(String(c ?? "")))
            .join(","),
        );
      }
    }
  } else if (includeHeaders) {
    lines.push(
      "REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,AS4DATE,AS4TIME,TARSYSTEM,RETCODE,MESSAGE",
    );
    if (includeSourceRow) {
      lines.push(sourceHeaderRow(false, useFm));
    }
    for (const req of requests) {
      lines.push(
        [...headerCells(req), req.retcode, req.message]
          .map((c) => escapeCell(String(c ?? "")))
          .join(","),
      );
    }
  }

  return lines.join("\n") + (lines.length ? "\n" : "");
}
