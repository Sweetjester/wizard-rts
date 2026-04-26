#!/usr/bin/env python3
"""Export the generated Kon 1.0 PixelLab library into a review gallery."""

from __future__ import annotations

import html
import json
import shutil
import time
from pathlib import Path


SOURCE_ROOT = Path("assets/generated/pixellab/kon_1_0")
JOBS_PATH = Path("tools/pixellab/kon_1_0_jobs/pixellab_jobs.json")
REVIEW_ROOT = Path("assets/review/pixellab")
IMAGE_EXTENSIONS = {".png", ".webp", ".jpg", ".jpeg", ".gif"}


def safe_name(value: str) -> str:
    cleaned = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in value.strip())
    return cleaned.strip("._") or "item"


def load_jobs() -> dict[str, dict]:
    if not JOBS_PATH.exists():
        return {}
    with JOBS_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle).get("jobs", {})


def main() -> int:
    if not SOURCE_ROOT.exists():
        raise SystemExit(f"Missing generated asset root: {SOURCE_ROOT}")

    label = time.strftime("kon_1_0_%Y%m%d_%H%M%S")
    export_root = REVIEW_ROOT / label
    export_root.mkdir(parents=True, exist_ok=True)
    jobs = load_jobs()
    entries: list[dict] = []
    copied = 0

    for batch_dir in sorted(path for path in SOURCE_ROOT.iterdir() if path.is_dir()):
        for asset_dir in sorted(path for path in batch_dir.iterdir() if path.is_dir()):
            image_files = sorted(
                path for path in asset_dir.rglob("*")
                if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
            )
            if not image_files:
                continue
            review_asset_dir = export_root / safe_name(batch_dir.name) / safe_name(asset_dir.name)
            candidates_dir = review_asset_dir / "candidates"
            metadata_dir = review_asset_dir / "metadata"
            candidates_dir.mkdir(parents=True, exist_ok=True)
            metadata_dir.mkdir(parents=True, exist_ok=True)

            request_id = find_request_id(jobs, batch_dir.name, asset_dir.name)
            job = jobs.get(request_id, {}) if request_id else {}
            prompt = str((job.get("payload") or {}).get("description", ""))
            candidate_paths = []
            for index, source in enumerate(image_files, start=1):
                destination = candidates_dir / f"{index:03d}_{safe_name(source.name)}"
                shutil.copy2(source, destination)
                candidate_paths.append(str(destination.relative_to(export_root)))
                copied += 1

            (metadata_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
            (metadata_dir / "job.json").write_text(json.dumps(job, indent=2), encoding="utf-8")
            (review_asset_dir / "review_status.todo.json").write_text(json.dumps({
                "decision": "unreviewed",
                "selected_candidate": "",
                "notes": "",
                "import_target": "",
            }, indent=2), encoding="utf-8")
            entries.append({
                "batch": batch_dir.name,
                "asset": asset_dir.name,
                "request_id": request_id,
                "status": job.get("status", "local_files"),
                "prompt": prompt,
                "candidate_files": candidate_paths,
            })

    summary = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source_root": str(SOURCE_ROOT),
        "export_root": str(export_root),
        "asset_folders": len(entries),
        "copied_files": copied,
        "entries": entries,
    }
    (export_root / "_review_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_gallery(export_root, summary)
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    (REVIEW_ROOT / "_latest_kon_1_0_review.json").write_text(json.dumps({
        "latest": str(export_root),
        "index": str(export_root / "index.html"),
    }, indent=2), encoding="utf-8")
    print(json.dumps({k: summary[k] for k in ("export_root", "asset_folders", "copied_files")}, indent=2))
    return 0


def find_request_id(jobs: dict[str, dict], batch: str, asset: str) -> str:
    prefix = f"{batch}/{asset}/"
    for request_id in jobs:
        if request_id.startswith(prefix):
            return request_id
    return ""


def write_gallery(export_root: Path, summary: dict) -> None:
    cards = []
    for entry in summary["entries"]:
        images = "".join(
            f'<a class="thumb" href="{html.escape(path.replace("\\", "/"))}">'
            f'<img src="{html.escape(path.replace("\\", "/"))}" loading="lazy"></a>'
            for path in entry["candidate_files"]
        )
        prompt = html.escape(entry["prompt"])
        cards.append(f"""
        <section class="card">
          <div class="card-head">
            <div>
              <h2>{html.escape(entry["asset"])}</h2>
              <p>{html.escape(entry["batch"])} / {html.escape(entry["status"])}</p>
            </div>
            <code>{html.escape(entry["request_id"])}</code>
          </div>
          <div class="grid">{images}</div>
          <details><summary>Prompt</summary><pre>{prompt}</pre></details>
        </section>
        """)
    (export_root / "index.html").write_text(f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kon 1.0 PixelLab Review</title>
<style>
:root {{ color-scheme: dark; --bg:#07100d; --panel:#111b16; --line:#2b4437; --text:#eee8da; --muted:#9daf9e; --cyan:#7ddde8; }}
body {{ margin:0; background:var(--bg); color:var(--text); font:14px/1.45 system-ui, Segoe UI, sans-serif; }}
header {{ position:sticky; top:0; z-index:2; padding:18px 24px; background:rgba(7,16,13,.96); border-bottom:1px solid var(--line); }}
h1,h2 {{ margin:0; letter-spacing:0; }}
header p,.card p {{ margin:4px 0 0; color:var(--muted); }}
main {{ display:grid; gap:16px; padding:20px; }}
.card {{ background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:16px; }}
.card-head {{ display:flex; justify-content:space-between; gap:12px; align-items:flex-start; margin-bottom:12px; }}
code {{ color:var(--cyan); font-size:12px; overflow-wrap:anywhere; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(132px,1fr)); gap:12px; align-items:center; }}
.thumb {{ display:grid; place-items:center; min-height:132px; background:#050807; border:1px solid #1f3028; border-radius:6px; padding:8px; }}
img {{ max-width:100%; max-height:240px; image-rendering:pixelated; }}
details {{ margin-top:12px; }}
pre {{ white-space:pre-wrap; color:var(--muted); }}
</style>
</head>
<body>
<header>
<h1>Kon 1.0 PixelLab Review</h1>
<p>{summary["asset_folders"]} asset folders / {summary["copied_files"]} image files copied from {html.escape(summary["source_root"])}</p>
</header>
<main>{''.join(cards)}</main>
</body>
</html>""", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
