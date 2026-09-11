const form = document.getElementById("extract-form");
const runBtn = document.getElementById("run-btn");
const downloadBtn = document.getElementById("download-btn");
const statusBar = document.getElementById("status-bar");
const tableWrap = document.getElementById("table-wrap");
const tbody = document.querySelector("#result-table tbody");
const adapterPill = document.getElementById("adapter-pill");

let lastPayload = null;

function payloadFromForm() {
  return {
    requests: document.getElementById("requests").value,
    owner: document.getElementById("owner").value,
    status: document.getElementById("status").value,
    category: document.getElementById("category").value,
    dateFrom: document.getElementById("dateFrom").value,
    dateTo: document.getElementById("dateTo").value,
    max: Number(document.getElementById("max").value || 500),
    includeHeaders: document.getElementById("includeHeaders").checked,
    includeObjects: document.getElementById("includeObjects").checked,
    useFm: document.getElementById("useFm").checked,
  };
}

function setStatus(text, kind = "") {
  statusBar.textContent = text;
  statusBar.classList.remove("is-error", "is-ok");
  if (kind) statusBar.classList.add(kind);
}

function renderTable(requests) {
  tbody.innerHTML = "";
  for (const req of requests) {
    const tr = document.createElement("tr");
    const retBad = req.retcode && req.retcode !== "000";
    tr.innerHTML = `
      <td>${escapeHtml(req.request)}</td>
      <td>${escapeHtml(req.description || req.message || "—")}</td>
      <td>${escapeHtml(req.owner || "—")}</td>
      <td>${escapeHtml(req.status || "—")}</td>
      <td>${req.objects?.length ?? 0}</td>
      <td class="${retBad ? "ret-bad" : ""}">${escapeHtml(req.retcode || "000")}</td>
    `;
    tbody.appendChild(tr);
  }
  tableWrap.hidden = requests.length === 0;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function boot() {
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    adapterPill.hidden = false;
    adapterPill.textContent = `adapter: ${data.adapter}`;
  } catch {
    adapterPill.hidden = false;
    adapterPill.textContent = "adapter: unknown";
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  lastPayload = payloadFromForm();
  runBtn.disabled = true;
  downloadBtn.disabled = true;
  setStatus(
    lastPayload.useFm
      ? "Calling CTS_API_READ_CHANGE_REQUEST…"
      : "Extracting via bulk CTS tables…",
  );

  try {
    const res = await fetch("/api/extract", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(lastPayload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Extract failed");

    renderTable(data.requests || []);
    downloadBtn.disabled = !(data.requests && data.requests.length);
    setStatus(
      `${data.ok} ok · ${data.failed} failed · ${data.requests.length} request(s) · ${data.adapter}`,
      data.failed ? "" : "is-ok",
    );
  } catch (err) {
    renderTable([]);
    setStatus(err.message || String(err), "is-error");
  } finally {
    runBtn.disabled = false;
  }
});

downloadBtn.addEventListener("click", async () => {
  if (!lastPayload) return;
  downloadBtn.disabled = true;
  setStatus("Building CSV…");
  try {
    const res = await fetch("/api/extract.csv", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(lastPayload),
    });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || "CSV download failed");
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    const disposition = res.headers.get("Content-Disposition") || "";
    const match = /filename="([^"]+)"/.exec(disposition);
    a.href = url;
    a.download = match?.[1] || "cts_extract.csv";
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
    setStatus("CSV downloaded.", "is-ok");
  } catch (err) {
    setStatus(err.message || String(err), "is-error");
  } finally {
    downloadBtn.disabled = false;
  }
});

boot();
