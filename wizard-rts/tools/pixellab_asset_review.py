#!/usr/bin/env python3
"""Build a review-ready folder and gallery from PixelLab outputs."""

from __future__ import annotations

import html
import json
import shutil
import time
from pathlib import Path
from typing import Any
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pixellab_asset_generator import (
    DEFAULT_JOBS_DIR,
    DEFAULT_MANIFEST,
    IMAGE_EXTENSIONS,
    PlannedRequest,
    load_job_store,
    load_manifest,
    plan_requests,
    safe_filename,
)


DEFAULT_REVIEW_ROOT = Path("assets/review/pixellab")


def build_review_export(
    manifest_path: Path = DEFAULT_MANIFEST,
    jobs_dir: Path = DEFAULT_JOBS_DIR,
    review_root: Path = DEFAULT_REVIEW_ROOT,
    label: str | None = None,
) -> dict[str, Any]:
    manifest = load_manifest(manifest_path)
    planned = plan_requests(manifest)
    job_store_path = jobs_dir / "pixellab_jobs.json"
    job_store = load_job_store(job_store_path)
    label = label or time.strftime("%Y%m%d_%H%M%S")
    export_root = review_root / safe_filename(label)
    export_root.mkdir(parents=True, exist_ok=True)

    entries: list[dict[str, Any]] = []
    copied_count = 0
    for index, request in enumerate(planned, start=1):
        entry, copied = export_request(export_root, index, request, job_store)
        entries.append(entry)
        copied_count += copied

    manifest_copy = export_root / "_manifest.json"
    manifest_copy.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    summary = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "export_root": str(export_root),
        "manifest": str(manifest_path),
        "jobs": str(job_store_path),
        "planned_assets": len(planned),
        "copied_files": copied_count,
        "entries": entries,
    }
    (export_root / "_review_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_gallery(export_root, summary)
    write_latest_pointer(review_root, export_root)
    return summary


def export_request(export_root: Path, index: int, request: PlannedRequest, job_store: dict[str, Any]) -> tuple[dict[str, Any], int]:
    batch_dir = export_root / f"{index:02d}_{safe_filename(request.batch_id)}"
    asset_dir = batch_dir / safe_filename(request.asset_id)
    candidates_dir = asset_dir / "candidates"
    metadata_dir = asset_dir / "metadata"
    candidates_dir.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)

    job = job_store.get("jobs", {}).get(request.request_id, {})
    source_files = collect_source_files(request.output_dir, job)
    copied: list[str] = []
    for source_index, source in enumerate(source_files, start=1):
        destination = candidates_dir / f"{source_index:02d}_{safe_filename(source.name)}"
        shutil.copy2(source, destination)
        copied.append(str(destination.relative_to(export_root)))

    prompt = str(request.payload.get("description", ""))
    (metadata_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    (metadata_dir / "request.json").write_text(json.dumps(request.payload, indent=2), encoding="utf-8")
    (metadata_dir / "job.json").write_text(json.dumps(job, indent=2), encoding="utf-8")
    status_path = asset_dir / "review_status.todo.json"
    if not status_path.exists():
        status_path.write_text(json.dumps({
            "decision": "unreviewed",
            "selected_candidate": "",
            "notes": "",
            "import_target": "",
        }, indent=2), encoding="utf-8")

    entry = {
        "request_id": request.request_id,
        "batch_id": request.batch_id,
        "asset_id": request.asset_id,
        "kind": request.kind,
        "endpoint": request.endpoint,
        "status": job.get("status", "not_submitted"),
        "source_output_dir": str(request.output_dir),
        "review_dir": str(asset_dir.relative_to(export_root)),
        "candidate_files": copied,
        "candidate_count": len(copied),
        "prompt": prompt,
    }
    return entry, len(copied)


def collect_source_files(output_dir: Path, job: dict[str, Any]) -> list[Path]:
    files: list[Path] = []
    for saved in job.get("saved_files", []) or []:
        path = Path(saved)
        if path.exists() and path.suffix.lower() in IMAGE_EXTENSIONS:
            files.append(path)
    if output_dir.exists():
        for path in sorted(output_dir.rglob("*")):
            if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS and path not in files:
                files.append(path)
    return files


def write_latest_pointer(review_root: Path, export_root: Path) -> None:
    review_root.mkdir(parents=True, exist_ok=True)
    (review_root / "_latest_review.json").write_text(json.dumps({
        "latest": str(export_root),
        "index": str(export_root / "index.html"),
    }, indent=2), encoding="utf-8")


def write_gallery(export_root: Path, summary: dict[str, Any]) -> None:
    cards = []
    for entry in summary["entries"]:
        images = []
        for candidate in entry["candidate_files"]:
            image_src = html.escape(candidate.replace("\\", "/"))
            images.append(f'<a class="thumb" href="{image_src}"><img src="{image_src}" loading="lazy" /></a>')
        if not images:
            images.append('<div class="empty">No downloaded candidate yet</div>')
        prompt = html.escape(entry["prompt"])
        cards.append(f"""
        <section class="card">
          <div class="card-head">
            <div>
              <h2>{html.escape(entry["asset_id"])}</h2>
              <p>{html.escape(entry["batch_id"])} / {html.escape(entry["kind"])} / {html.escape(entry["status"])}</p>
            </div>
            <code>{html.escape(entry["request_id"])}</code>
          </div>
          <div class="grid">{''.join(images)}</div>
          <details><summary>Prompt</summary><pre>{prompt}</pre></details>
          <p class="path">{html.escape(entry["review_dir"])}</p>
        </section>
        """)

    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Wizard RTS PixelLab Review</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg: #07100d;
      --panel: #101915;
      --line: #26372f;
      --text: #e7e2d5;
      --muted: #a8b3a7;
      --accent: #7ddde8;
      --blood: #c13030;
    }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font: 14px/1.45 system-ui, Segoe UI, sans-serif;
    }}
    header {{
      position: sticky;
      top: 0;
      z-index: 2;
      background: rgba(7, 16, 13, 0.94);
      border-bottom: 1px solid var(--line);
      padding: 18px 24px;
    }}
    h1, h2 {{ margin: 0; letter-spacing: 0; }}
    header p, .card-head p, .path {{ color: var(--muted); margin: 4px 0 0; }}
    main {{
      display: grid;
      gap: 16px;
      padding: 20px;
    }}
    .card {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 16px;
    }}
    .card-head {{
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: start;
      margin-bottom: 12px;
    }}
    code {{
      color: var(--accent);
      font-size: 12px;
      overflow-wrap: anywhere;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(132px, 1fr));
      gap: 12px;
      align-items: center;
    }}
    .thumb {{
      display: grid;
      place-items: center;
      min-height: 132px;
      background: #050807;
      border: 1px solid #1f3028;
      border-radius: 6px;
      padding: 8px;
    }}
    img {{
      max-width: 100%;
      max-height: 220px;
      image-rendering: pixelated;
    }}
    .empty {{
      min-height: 96px;
      display: grid;
      place-items: center;
      color: var(--muted);
      border: 1px dashed var(--line);
      border-radius: 6px;
    }}
    details {{ margin-top: 12px; }}
    summary {{ color: var(--accent); cursor: pointer; }}
    pre {{
      white-space: pre-wrap;
      color: #d6c7ae;
      background: #07100d;
      padding: 12px;
      border-radius: 6px;
      overflow-x: auto;
    }}
  </style>
</head>
<body>
  <header>
    <h1>Wizard RTS PixelLab Review</h1>
    <p>{summary["copied_files"]} candidate file(s), {summary["planned_assets"]} planned asset(s), created {html.escape(summary["created_at"])}</p>
  </header>
  <main>{''.join(cards)}</main>
</body>
</html>
"""
    (export_root / "index.html").write_text(document, encoding="utf-8")


def main() -> int:
    summary = build_review_export()
    print(json.dumps({
        "export_root": summary["export_root"],
        "index": str(Path(summary["export_root"]) / "index.html"),
        "copied_files": summary["copied_files"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
