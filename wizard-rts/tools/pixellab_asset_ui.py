#!/usr/bin/env python3
"""Local browser UI for the PixelLab asset pipeline."""

from __future__ import annotations

import argparse
import json
import os
import sys
import threading
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pixellab_asset_generator import (
    DEFAULT_API_BASE,
    DEFAULT_JOBS_DIR,
    DEFAULT_MANIFEST,
    PixelLabClient,
    PixelLabError,
    load_job_store,
    load_manifest,
    plan_requests,
    poll_jobs,
    submit_requests,
)
from pixellab_asset_review import DEFAULT_REVIEW_ROOT, build_review_export


class AssetUiServer(ThreadingHTTPServer):
    def __init__(self, address: tuple[str, int], handler: type[BaseHTTPRequestHandler], repo_root: Path) -> None:
        super().__init__(address, handler)
        self.repo_root = repo_root
        self.manifest_path = DEFAULT_MANIFEST
        self.jobs_dir = DEFAULT_JOBS_DIR
        self.review_root = DEFAULT_REVIEW_ROOT
        self.api_base = os.environ.get("PIXELLAB_API_BASE", DEFAULT_API_BASE)
        self.api_key = os.environ.get("PIXELLAB_API_KEY", "")
        self.lock = threading.Lock()


class AssetUiHandler(BaseHTTPRequestHandler):
    server: AssetUiServer

    def do_GET(self) -> None:
        try:
            if self.path == "/" or self.path == "/index.html":
                self.respond_text(INDEX_HTML, "text/html; charset=utf-8")
                return
            if self.path == "/api/plan":
                self.respond_json({"requests": [planned_to_dict(item) for item in current_plan()]})
                return
            if self.path == "/api/jobs":
                self.respond_json(current_jobs())
                return
            if self.path == "/api/review/latest":
                latest = self.latest_review()
                self.respond_json(latest)
                return
            if self.path.startswith("/review/"):
                self.serve_review_file()
                return
            self.send_error(HTTPStatus.NOT_FOUND)
        except Exception as exc:
            self.respond_error(exc)

    def do_POST(self) -> None:
        try:
            payload = self.read_json()
            if self.path == "/api/key":
                self.server.api_key = str(payload.get("api_key", "")).strip()
                self.respond_json({"has_key": bool(self.server.api_key)})
                return
            if self.path == "/api/balance":
                self.respond_json(self.client_from_payload(payload).get("/balance"))
                return
            if self.path == "/api/submit":
                self.handle_submit(payload)
                return
            if self.path == "/api/poll":
                self.handle_poll(payload)
                return
            if self.path == "/api/review/build":
                self.handle_review_build(payload)
                return
            self.send_error(HTTPStatus.NOT_FOUND)
        except Exception as exc:
            self.respond_error(exc)

    def handle_submit(self, payload: dict[str, Any]) -> None:
        dry_run = bool(payload.get("dry_run", False))
        max_submit = int(payload.get("max_submit", 0) or 0)
        manifest = load_manifest(self.server.manifest_path)
        planned = plan_requests(manifest)
        jobs_path = self.server.jobs_dir / "pixellab_jobs.json"
        job_store = load_job_store(jobs_path)
        client = PixelLabClient("dry-run", self.server.api_base) if dry_run else self.client_from_payload(payload)
        with self.server.lock:
            submit_requests(client, planned, job_store, jobs_path, dry_run, max_submit)
        self.respond_json(current_jobs())

    def handle_poll(self, payload: dict[str, Any]) -> None:
        jobs_path = self.server.jobs_dir / "pixellab_jobs.json"
        job_store = load_job_store(jobs_path)
        with self.server.lock:
            remaining = poll_jobs(self.client_from_payload(payload), job_store, jobs_path)
        result = current_jobs()
        result["remaining"] = remaining
        self.respond_json(result)

    def handle_review_build(self, payload: dict[str, Any]) -> None:
        label = str(payload.get("label", "")).strip() or None
        summary = build_review_export(
            manifest_path=self.server.manifest_path,
            jobs_dir=self.server.jobs_dir,
            review_root=self.server.review_root,
            label=label,
        )
        relative_index = Path(summary["export_root"]).relative_to(self.server.review_root) / "index.html"
        summary["review_url"] = f"/review/{relative_index.as_posix()}"
        self.respond_json(summary)

    def client_from_payload(self, payload: dict[str, Any]) -> PixelLabClient:
        key = str(payload.get("api_key", "")).strip() or self.server.api_key
        if key:
            self.server.api_key = key
        if not key:
            raise PixelLabError("API key is not set. Paste it into the UI or set PIXELLAB_API_KEY.")
        return PixelLabClient(key, self.server.api_base)

    def latest_review(self) -> dict[str, Any]:
        pointer_path = self.server.review_root / "_latest_review.json"
        if not pointer_path.exists():
            return {"exists": False}
        data = json.loads(pointer_path.read_text(encoding="utf-8"))
        index = Path(data["index"])
        return {
            "exists": index.exists(),
            "index": str(index),
            "review_url": f"/review/{index.relative_to(self.server.review_root).as_posix()}",
        }

    def serve_review_file(self) -> None:
        relative = self.path.removeprefix("/review/").split("?", 1)[0]
        target = (self.server.review_root / relative).resolve()
        root = self.server.review_root.resolve()
        if not str(target).startswith(str(root)) or not target.exists() or not target.is_file():
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        content_type = "text/html; charset=utf-8"
        if target.suffix.lower() == ".png":
            content_type = "image/png"
        elif target.suffix.lower() == ".webp":
            content_type = "image/webp"
        elif target.suffix.lower() in {".jpg", ".jpeg"}:
            content_type = "image/jpeg"
        elif target.suffix.lower() == ".json":
            content_type = "application/json"
        data = target.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        return json.loads(raw) if raw else {}

    def respond_json(self, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def respond_text(self, payload: str, content_type: str) -> None:
        data = payload.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def respond_error(self, exc: Exception) -> None:
        status = HTTPStatus.BAD_REQUEST if isinstance(exc, PixelLabError) else HTTPStatus.INTERNAL_SERVER_ERROR
        data = json.dumps({"error": str(exc)}).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format: str, *args: Any) -> None:
        return


def current_plan() -> list[Any]:
    return plan_requests(load_manifest(DEFAULT_MANIFEST))


def current_jobs() -> dict[str, Any]:
    job_store = load_job_store(DEFAULT_JOBS_DIR / "pixellab_jobs.json")
    jobs = list(job_store.get("jobs", {}).values())
    counts: dict[str, int] = {}
    for job in jobs:
        status = str(job.get("status", "unknown"))
        counts[status] = counts.get(status, 0) + 1
    return {"jobs": jobs, "counts": counts}


def planned_to_dict(request: Any) -> dict[str, Any]:
    size = request.payload.get("image_size", {})
    return {
        "request_id": request.request_id,
        "batch_id": request.batch_id,
        "asset_id": request.asset_id,
        "kind": request.kind,
        "endpoint": request.endpoint,
        "width": size.get("width"),
        "height": size.get("height"),
        "output_dir": str(request.output_dir),
        "followup_count": len(request.followups),
        "prompt": request.payload.get("description", ""),
    }


INDEX_HTML = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Wizard RTS PixelLab Assets</title>
  <style>
    :root { color-scheme: dark; --bg:#07100d; --panel:#101915; --line:#26372f; --text:#eee8da; --muted:#a8b3a7; --accent:#7ddde8; --blood:#c13030; }
    body { margin:0; background:var(--bg); color:var(--text); font:14px/1.45 system-ui, Segoe UI, sans-serif; }
    header { padding:18px 22px; border-bottom:1px solid var(--line); background:#09130f; display:flex; justify-content:space-between; gap:18px; align-items:center; }
    h1,h2 { margin:0; letter-spacing:0; }
    main { display:grid; grid-template-columns: 380px 1fr; gap:16px; padding:16px; }
    section { background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:14px; }
    label { display:block; color:var(--muted); margin:10px 0 4px; }
    input { width:100%; box-sizing:border-box; background:#050807; color:var(--text); border:1px solid var(--line); border-radius:6px; padding:9px; }
    button { background:#1e3a2d; color:var(--text); border:1px solid #4a8a5c; border-radius:6px; padding:9px 11px; cursor:pointer; margin:8px 6px 0 0; }
    button:hover { border-color:var(--accent); }
    button.danger { background:#2b0608; border-color:var(--blood); }
    table { width:100%; border-collapse:collapse; font-size:13px; }
    th,td { border-bottom:1px solid var(--line); padding:8px; text-align:left; vertical-align:top; }
    th { color:var(--muted); font-weight:600; }
    code { color:var(--accent); overflow-wrap:anywhere; }
    pre { background:#050807; border:1px solid var(--line); border-radius:6px; padding:10px; overflow:auto; max-height:240px; }
    .muted { color:var(--muted); }
    .row { display:flex; gap:8px; align-items:center; }
    .row input { flex:1; }
    .pill { display:inline-block; border:1px solid var(--line); border-radius:999px; padding:2px 8px; color:var(--muted); margin-right:4px; }
    @media (max-width: 1000px) { main { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>Wizard RTS PixelLab Assets</h1>
      <div class="muted">Generate, poll, and export review galleries from the manifest.</div>
    </div>
    <div id="status" class="muted">Loading...</div>
  </header>
  <main>
    <section>
      <h2>Controls</h2>
      <label>PixelLab API key</label>
      <input id="apiKey" type="password" placeholder="Runtime only. Not saved to disk.">
      <label>Max submit</label>
      <input id="maxSubmit" type="number" min="0" value="1">
      <label>Review label</label>
      <input id="reviewLabel" placeholder="optional, e.g. kon-pass-01">
      <button onclick="saveKey()">Use Key</button>
      <button onclick="balance()">Balance</button>
      <button onclick="submitJobs(false)">Submit</button>
      <button onclick="submitJobs(true)">Dry Run</button>
      <button onclick="pollJobs()">Poll</button>
      <button onclick="buildReview()">Build Review</button>
      <button class="danger" onclick="refreshAll()">Refresh</button>
      <pre id="log"></pre>
    </section>
    <section>
      <h2>Job Status</h2>
      <div id="counts" class="muted"></div>
      <table>
        <thead><tr><th>Asset</th><th>Status</th><th>Kind</th><th>Output</th></tr></thead>
        <tbody id="jobs"></tbody>
      </table>
    </section>
    <section>
      <h2>Manifest Plan</h2>
      <table>
        <thead><tr><th>Asset</th><th>Endpoint</th><th>Size</th><th>Prompt</th></tr></thead>
        <tbody id="plan"></tbody>
      </table>
    </section>
  </main>
  <script>
    const $ = id => document.getElementById(id);
    function setLog(value) { $('log').textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2); }
    async function api(path, body) {
      const response = await fetch(path, { method: body ? 'POST' : 'GET', headers: {'Content-Type':'application/json'}, body: body ? JSON.stringify(body) : undefined });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || response.statusText);
      return data;
    }
    function payload(extra={}) { return { api_key: $('apiKey').value, ...extra }; }
    async function saveKey() { setLog(await api('/api/key', payload())); }
    async function balance() { try { setLog(await api('/api/balance', payload())); } catch(e) { setLog(e.message); } }
    async function submitJobs(dryRun) {
      try {
        const maxSubmit = Number($('maxSubmit').value || 0);
        renderJobs(await api('/api/submit', payload({ dry_run: dryRun, max_submit: maxSubmit })));
      } catch(e) { setLog(e.message); }
    }
    async function pollJobs() { try { renderJobs(await api('/api/poll', payload())); } catch(e) { setLog(e.message); } }
    async function buildReview() {
      try {
        const data = await api('/api/review/build', { label: $('reviewLabel').value });
        setLog(data);
        if (data.review_url) window.open(data.review_url, '_blank');
      } catch(e) { setLog(e.message); }
    }
    async function refreshAll() {
      const plan = await api('/api/plan');
      renderPlan(plan.requests);
      renderJobs(await api('/api/jobs'));
    }
    function renderPlan(items) {
      $('plan').innerHTML = items.map(item => `<tr><td><code>${item.request_id}</code><br><span class="muted">${item.followup_count} followups</span></td><td>${item.endpoint}</td><td>${item.width}x${item.height}</td><td>${escapeHtml(item.prompt).slice(0, 260)}</td></tr>`).join('');
      $('status').textContent = `${items.length} planned requests`;
    }
    function renderJobs(data) {
      const counts = data.counts || {};
      $('counts').innerHTML = Object.keys(counts).map(k => `<span class="pill">${k}: ${counts[k]}</span>`).join('') || 'No jobs yet';
      $('jobs').innerHTML = (data.jobs || []).map(job => `<tr><td><code>${job.request_id}</code></td><td>${job.status || ''}</td><td>${job.kind || ''}</td><td>${escapeHtml(job.output_dir || '')}</td></tr>`).join('');
      setLog(data);
    }
    function escapeHtml(value) {
      return String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
    }
    refreshAll().catch(e => setLog(e.message));
  </script>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the local PixelLab asset UI.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    repo_root = Path.cwd()
    server = AssetUiServer((args.host, args.port), AssetUiHandler, repo_root)
    url = f"http://{args.host}:{args.port}/"
    print(f"[pixellab-ui] serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
