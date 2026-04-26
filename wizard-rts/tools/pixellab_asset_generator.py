#!/usr/bin/env python3
"""Batch PixelLab asset generation for Wizard RTS.

The API token is intentionally read from PIXELLAB_API_KEY. Do not put secrets in
manifests or commit them to the repository.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


DEFAULT_API_BASE = "https://api.pixellab.ai/v2"
DEFAULT_MANIFEST = Path("tools/pixellab_asset_manifest.json")
DEFAULT_JOBS_DIR = Path("tools/pixellab/jobs")
IMAGE_EXTENSIONS = {".png", ".webp", ".jpg", ".jpeg", ".gif", ".zip"}


class PixelLabError(RuntimeError):
    pass


@dataclass(frozen=True)
class PlannedRequest:
    batch_id: str
    asset_id: str
    kind: str
    endpoint: str
    payload: dict[str, Any]
    output_dir: Path
    followups: list[dict[str, Any]] = field(default_factory=list)

    @property
    def request_id(self) -> str:
        return f"{self.batch_id}/{self.asset_id}/{self.kind}"


class PixelLabClient:
    def __init__(self, api_key: str, api_base: str = DEFAULT_API_BASE, timeout: int = 60) -> None:
        self.api_key = api_key
        self.api_base = api_base.rstrip("/")
        self.timeout = timeout

    def get(self, path: str) -> dict[str, Any]:
        return self._request("GET", path, None)

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request("POST", path, payload)

    def download(self, url: str) -> bytes:
        request = urllib.request.Request(url, headers={"User-Agent": "wizard-rts-pixellab-generator/1.0"})
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            return response.read()

    def _request(self, method: str, path: str, payload: dict[str, Any] | None) -> dict[str, Any]:
        url = f"{self.api_base}/{path.lstrip('/')}"
        body = None
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "application/json",
            "User-Agent": "wizard-rts-pixellab-generator/1.0",
        }
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise PixelLabError(f"{method} {path} failed with HTTP {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise PixelLabError(f"{method} {path} failed: {exc.reason}") from exc
        if not raw:
            return {}
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise PixelLabError(f"{method} {path} returned non-JSON data") from exc
        if isinstance(parsed, dict) and parsed.get("success") is False:
            raise PixelLabError(f"{method} {path} failed: {parsed.get('error')}")
        return parsed


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Wizard RTS assets through PixelLab.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--jobs-dir", type=Path, default=DEFAULT_JOBS_DIR)
    parser.add_argument("--api-base", default=os.environ.get("PIXELLAB_API_BASE", DEFAULT_API_BASE))
    parser.add_argument("--poll-seconds", type=float, default=8.0)
    parser.add_argument("--max-submit", type=int, default=0, help="Limit submitted requests; 0 means no limit.")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("plan", help="Validate the manifest and print planned requests.")
    submit = sub.add_parser("submit", help="Submit enabled manifest assets to PixelLab.")
    submit.add_argument("--dry-run", action="store_true")
    sub.add_parser("poll", help="Poll existing jobs and download finished assets.")
    run = sub.add_parser("run", help="Submit, then poll until all jobs finish.")
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--timeout-minutes", type=float, default=30.0)
    sub.add_parser("balance", help="Check PixelLab account balance.")
    args = parser.parse_args()

    manifest = load_manifest(args.manifest)
    planned = plan_requests(manifest)

    if args.command == "plan":
        print_plan(planned)
        return 0

    dry_run = bool(getattr(args, "dry_run", False))
    if args.command in {"submit", "poll", "run", "balance"} and not dry_run:
        api_key = os.environ.get("PIXELLAB_API_KEY", "").strip()
        if not api_key:
            raise PixelLabError("PIXELLAB_API_KEY is not set. Set it in your shell environment before calling the API.")
        client = PixelLabClient(api_key, args.api_base)
    elif dry_run:
        client = PixelLabClient("dry-run", args.api_base)

    if args.command == "balance":
        print(json.dumps(client.get("/balance"), indent=2))
        return 0

    args.jobs_dir.mkdir(parents=True, exist_ok=True)
    job_store_path = args.jobs_dir / "pixellab_jobs.json"
    job_store = load_job_store(job_store_path)

    if args.command == "submit":
        submit_requests(client, planned, job_store, job_store_path, args.dry_run, args.max_submit)
        return 0

    if args.command == "poll":
        poll_jobs(client, job_store, job_store_path)
        return 0

    if args.command == "run":
        submit_requests(client, planned, job_store, job_store_path, args.dry_run, args.max_submit)
        if args.dry_run:
            return 0
        deadline = time.time() + args.timeout_minutes * 60.0
        while time.time() < deadline:
            remaining = poll_jobs(client, job_store, job_store_path)
            if remaining == 0:
                return 0
            print(f"[pixellab] {remaining} job(s) still processing; polling again in {args.poll_seconds:.0f}s")
            time.sleep(args.poll_seconds)
        raise PixelLabError("Timed out waiting for PixelLab jobs to finish.")

    return 0


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    if "batches" not in manifest or not isinstance(manifest["batches"], list):
        raise PixelLabError("Manifest must contain a batches array.")
    return manifest


def plan_requests(manifest: dict[str, Any]) -> list[PlannedRequest]:
    style = manifest.get("style", {})
    output_root = Path(manifest.get("output_root", "assets/generated/pixellab"))
    planned: list[PlannedRequest] = []
    for batch in manifest["batches"]:
        if not batch.get("enabled", True):
            continue
        batch_id = slug(batch["id"])
        batch_type = batch["type"]
        for asset in batch.get("assets", []):
            if asset.get("disabled", False):
                continue
            variants = max(1, int(asset.get("variants", 1)))
            for variant_index in range(variants):
                base_asset_id = slug(asset["id"])
                asset_id = base_asset_id if variants == 1 else f"{base_asset_id}_{variant_index + 1:02d}"
                variant_suffix = "" if variants == 1 else " Variant %s of %s; keep the same footprint and camera angle but vary surface details." % (variant_index + 1, variants)
                description = compose_description(style, asset["description"] + variant_suffix)
                output_dir = output_root / batch_id / asset_id
                planned.extend(build_requests(batch_id, batch_type, batch, asset, asset_id, description, output_dir))
    return planned


def build_requests(
    batch_id: str,
    batch_type: str,
    batch: dict[str, Any],
    asset: dict[str, Any],
    asset_id: str,
    description: str,
    output_dir: Path,
) -> list[PlannedRequest]:
    if batch_type == "character_8dir":
        payload = {
            "description": description,
            "image_size": {"width": int(asset.get("size", batch.get("size", 64))), "height": int(asset.get("size", batch.get("size", 64)))},
            "mode": batch.get("mode", "standard"),
            "async_mode": True,
            "outline": batch.get("outline", "thin"),
            "shading": batch.get("shading", "soft"),
            "detail": batch.get("detail", "high"),
            "view": batch.get("view", "low top-down"),
            "isometric": bool(batch.get("isometric", True)),
            "proportions": asset.get("proportions", batch.get("proportions", {"type": "preset", "name": "stylized"})),
            "template_id": asset.get("template_id", batch.get("template_id", "mannequin")),
            "seed": asset.get("seed", batch.get("seed")),
            "output_type": "dict",
        }
        followups = []
        for animation in batch.get("animations", []):
            followups.append({
                "name": slug(animation.get("name", animation.get("template_animation_id", "animation"))),
                "endpoint": "/animate-character",
                "payload": strip_nulls({
                    "animation_name": animation.get("name"),
                    "description": description,
                    "action_description": animation.get("action_description"),
                    "template_animation_id": animation.get("template_animation_id"),
                    "frame_count": animation.get("frame_count", 8),
                    "async_mode": True,
                    "mode": animation.get("mode"),
                    "directions": animation.get("directions"),
                    "isometric": bool(batch.get("isometric", True)),
                    "seed": animation.get("seed", asset.get("seed", batch.get("seed"))),
                }),
            })
        return [PlannedRequest(batch_id, asset_id, "character", "/create-character-with-8-directions", strip_nulls(payload), output_dir, followups)]

    if batch_type == "character_animation":
        payload = {
            "character_id": asset["character_id"],
            "animation_name": asset.get("name", asset_id),
            "description": description,
            "action_description": asset.get("action_description"),
            "template_animation_id": asset.get("template_animation_id"),
            "frame_count": asset.get("frame_count", 8),
            "async_mode": True,
            "mode": asset.get("mode"),
            "directions": asset.get("directions"),
            "isometric": bool(batch.get("isometric", True)),
            "seed": asset.get("seed", batch.get("seed")),
        }
        return [PlannedRequest(batch_id, asset_id, "animation", "/animate-character", strip_nulls(payload), output_dir)]

    if batch_type == "map_object":
        width = int(asset.get("width", batch.get("width", 128)))
        height = int(asset.get("height", batch.get("height", 128)))
        payload = {
            "description": description,
            "image_size": {"width": width, "height": height},
            "seed": asset.get("seed", batch.get("seed")),
            "view": asset.get("view", batch.get("view", "low top-down")),
            "outline": asset.get("outline", batch.get("outline", "single color outline")),
            "shading": asset.get("shading", batch.get("shading", "medium shading")),
            "detail": asset.get("detail", batch.get("detail", "high detail")),
        }
        return [PlannedRequest(batch_id, asset_id, "image", "/map-objects", strip_nulls(payload), output_dir)]

    if batch_type == "image":
        width = int(asset["width"])
        height = int(asset["height"])
        endpoint = asset.get("endpoint", batch.get("endpoint", "generate-image-v2"))
        payload = {
            "description": description,
            "image_size": {"width": width, "height": height},
            "seed": asset.get("seed", batch.get("seed")),
            "no_background": bool(asset.get("no_background", batch.get("no_background", True))),
        }
        return [PlannedRequest(batch_id, asset_id, "image", f"/{endpoint.lstrip('/')}", strip_nulls(payload), output_dir)]

    if batch_type == "isometric_tile":
        size = int(asset.get("size", batch.get("size", 64)))
        payload = {
            "description": description,
            "image_size": {"width": size, "height": size},
            "isometric_tile_size": size,
            "isometric_tile_shape": asset.get("tile_shape", batch.get("tile_shape", "thin tile")),
            "outline": asset.get("outline", batch.get("outline", "lineless")),
            "shading": asset.get("shading", batch.get("shading", "soft")),
            "detail": asset.get("detail", batch.get("detail", "high")),
            "seed": asset.get("seed", batch.get("seed")),
        }
        return [PlannedRequest(batch_id, asset_id, "isometric_tile", "/create-isometric-tile", strip_nulls(payload), output_dir)]

    if batch_type == "tiles_pro":
        payload = {
            "description": description,
            "tile_type": batch.get("tile_type", "isometric"),
            "tile_size": int(batch.get("tile_size", 64)),
            "tile_height": batch.get("tile_height"),
            "tile_view": batch.get("tile_view", "low top-down"),
            "tile_depth_ratio": batch.get("tile_depth_ratio"),
            "outline_mode": batch.get("outline_mode", "lineless"),
            "seed": asset.get("seed", batch.get("seed")),
        }
        return [PlannedRequest(batch_id, asset_id, "tiles_pro", "/create-tiles-pro", strip_nulls(payload), output_dir)]

    raise PixelLabError(f"Unknown batch type: {batch_type}")


def submit_requests(
    client: PixelLabClient,
    planned: list[PlannedRequest],
    job_store: dict[str, Any],
    job_store_path: Path,
    dry_run: bool,
    max_submit: int,
) -> None:
    submitted = 0
    for request in planned:
        existing = job_store["jobs"].get(request.request_id)
        if existing and existing.get("status") in {"submitted", "processing", "completed"}:
            continue
        if max_submit and submitted >= max_submit:
            break
        print(f"[pixellab] submit {request.request_id} -> {request.endpoint}")
        if dry_run:
            print(json.dumps(request.payload, indent=2))
            submitted += 1
            continue
        try:
            response = client.post(request.endpoint, request.payload)
        except PixelLabError as exc:
            if "Maximum 8 concurrent background jobs allowed" in str(exc) or "HTTP 429" in str(exc):
                print(f"[pixellab] queue full; submitted {submitted} new request(s), retry later")
                break
            if "Insufficient resources" in str(exc) or "HTTP 402" in str(exc):
                print(f"[pixellab] generation allowance exhausted; submitted {submitted} new request(s)")
                break
            raise
        job_id = find_job_id(response)
        entity_id = find_entity_id(response, ["character_id", "tileset_id", "tile_id", "generation_id", "id"])
        status = "completed" if job_id is None else "submitted"
        job_store["jobs"][request.request_id] = {
            "request_id": request.request_id,
            "batch_id": request.batch_id,
            "asset_id": request.asset_id,
            "kind": request.kind,
            "endpoint": request.endpoint,
            "payload": request.payload,
            "followups": request.followups,
            "output_dir": str(request.output_dir),
            "job_id": job_id,
            "entity_id": entity_id,
            "status": status,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "response": response,
        }
        if job_id is None:
            save_outputs(response, request.output_dir, request.asset_id)
        submitted += 1
        save_job_store(job_store_path, job_store)
    print(f"[pixellab] submitted {submitted} new request(s)")


def poll_jobs(client: PixelLabClient, job_store: dict[str, Any], job_store_path: Path) -> int:
    remaining = 0
    for request_id, job in list(job_store["jobs"].items()):
        if job.get("status") in {"completed", "failed"}:
            continue
        job_id = job.get("job_id")
        if not job_id:
            job["status"] = "completed"
            continue
        print(f"[pixellab] poll {request_id} job={job_id}")
        response = client.get(f"/background-jobs/{urllib.parse.quote(str(job_id))}")
        normalized = normalize_job_response(response)
        job["last_response"] = response
        job["status"] = normalized["status"]
        if normalized["status"] == "completed":
            saved = save_outputs(response, Path(job["output_dir"]), job["asset_id"])
            job["saved_files"] = [str(path) for path in saved]
            print(f"[pixellab] completed {request_id}; saved {len(saved)} file(s)")
            remaining += submit_followups(client, job_store, request_id, job)
        elif normalized["status"] == "failed":
            job["error"] = normalized.get("error", "unknown PixelLab failure")
            print(f"[pixellab] failed {request_id}: {job['error']}")
        else:
            remaining += 1
    save_job_store(job_store_path, job_store)
    return remaining


def submit_followups(client: PixelLabClient, job_store: dict[str, Any], parent_request_id: str, job: dict[str, Any]) -> int:
    followups = job.get("followups") or []
    if not followups or job.get("followups_submitted"):
        return 0
    character_id = job.get("entity_id") or find_entity_id(job.get("last_response") or job.get("response") or {}, ["character_id", "id"])
    if not character_id:
        print(f"[pixellab] cannot submit followups for {parent_request_id}; no character_id found")
        return 0
    submitted = 0
    for followup in followups:
        name = slug(str(followup["name"]))
        request_id = f"{parent_request_id}/animation_{name}"
        existing = job_store["jobs"].get(request_id)
        if existing and existing.get("status") in {"submitted", "processing", "completed"}:
            continue
        payload = dict(followup["payload"])
        payload["character_id"] = character_id
        print(f"[pixellab] submit followup {request_id} -> {followup['endpoint']}")
        try:
            response = client.post(followup["endpoint"], payload)
        except PixelLabError as exc:
            if "Maximum 8 concurrent background jobs allowed" in str(exc) or "HTTP 429" in str(exc):
                print(f"[pixellab] followup queue full after {submitted} animation request(s); retry later")
                return submitted
            job_store["jobs"][request_id] = {
                "request_id": request_id,
                "batch_id": job["batch_id"],
                "asset_id": f"{job['asset_id']}_{name}",
                "kind": "animation",
                "endpoint": followup["endpoint"],
                "payload": payload,
                "output_dir": str(Path(job["output_dir"]) / "animations" / name),
                "job_id": null_string(),
                "entity_id": null_string(),
                "status": "failed",
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "error": str(exc),
            }
            print(f"[pixellab] followup failed {request_id}: {exc}")
            continue
        job_id = find_job_id(response)
        entity_id = find_entity_id(response, ["character_id", "animation_id", "id"])
        output_dir = Path(job["output_dir"]) / "animations" / name
        job_store["jobs"][request_id] = {
            "request_id": request_id,
            "batch_id": job["batch_id"],
            "asset_id": f"{job['asset_id']}_{name}",
            "kind": "animation",
            "endpoint": followup["endpoint"],
            "payload": payload,
            "output_dir": str(output_dir),
            "job_id": job_id,
            "entity_id": entity_id,
            "status": "completed" if job_id is None else "submitted",
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "response": response,
        }
        if job_id is None:
            save_outputs(response, output_dir, f"{job['asset_id']}_{name}")
        else:
            submitted += 1
    job["followups_submitted"] = True
    return submitted


def null_string() -> str:
    return ""


def normalize_job_response(response: dict[str, Any]) -> dict[str, Any]:
    data = response.get("data", response)
    status = str(data.get("status", data.get("state", ""))).lower()
    if status in {"completed", "complete", "succeeded", "success", "done"} or has_asset_payload(data):
        return {"status": "completed"}
    if status in {"failed", "error"}:
        return {"status": "failed", "error": data.get("error") or data.get("message")}
    return {"status": "processing"}


def save_outputs(response: dict[str, Any], output_dir: Path, asset_id: str) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    saved: list[Path] = []
    for index, item in enumerate(extract_asset_items(response)):
        filename = item.get("filename") or f"{asset_id}_{index + 1:02d}.{item['extension']}"
        path = unique_path(output_dir / safe_filename(filename))
        if item["type"] == "base64":
            path.write_bytes(base64.b64decode(item["data"]))
        elif item["type"] == "url":
            path.write_bytes(download_public_url(item["url"]))
        saved.append(path)
    (output_dir / f"{asset_id}_response.json").write_text(json.dumps(response, indent=2), encoding="utf-8")
    return saved


def download_public_url(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "wizard-rts-pixellab-generator/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def extract_asset_items(value: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []

    def visit(node: Any, hint: str = "asset") -> None:
        if isinstance(node, dict):
            if "base64" in node and isinstance(node["base64"], str):
                fmt = str(node.get("format", "png")).lower().lstrip(".")
                found.append({"type": "base64", "data": node["base64"], "extension": fmt, "filename": f"{hint}.{fmt}"})
            for key, child in node.items():
                key_lower = str(key).lower()
                if isinstance(child, str) and looks_like_download_url(child):
                    found.append({"type": "url", "url": child, "extension": extension_for_url(child), "filename": f"{key_lower}.{extension_for_url(child)}"})
                else:
                    visit(child, key_lower)
        elif isinstance(node, list):
            for idx, child in enumerate(node):
                visit(child, f"{hint}_{idx + 1:02d}")

    visit(value)
    deduped: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in found:
        marker = item.get("data") or item.get("url")
        if marker in seen:
            continue
        seen.add(marker)
        deduped.append(item)
    return deduped


def has_asset_payload(value: Any) -> bool:
    return bool(extract_asset_items(value))


def looks_like_download_url(value: str) -> bool:
    if not value.startswith(("http://", "https://")):
        return False
    parsed = urllib.parse.urlparse(value)
    suffix = Path(parsed.path).suffix.lower()
    if suffix in IMAGE_EXTENSIONS:
        return True
    return any(token in parsed.path.lower() for token in ["/download", "/zip", "/image", "/asset"])


def extension_for_url(url: str) -> str:
    suffix = Path(urllib.parse.urlparse(url).path).suffix.lower().lstrip(".")
    return suffix if suffix else "png"


def find_job_id(response: dict[str, Any]) -> str | None:
    candidates = ["background_job_id", "job_id", "task_id"]
    stack: list[Any] = [response.get("data", response)]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            for key in candidates:
                if key in node and node[key]:
                    return str(node[key])
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return None


def find_entity_id(response: dict[str, Any], keys: list[str]) -> str | None:
    stack: list[Any] = [response.get("data", response)]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            for key in keys:
                if key in node and node[key]:
                    return str(node[key])
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return None


def load_job_store(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": 1, "jobs": {}}
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_job_store(path: Path, job_store: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(job_store, indent=2), encoding="utf-8")


def print_plan(planned: list[PlannedRequest]) -> None:
    print(f"[pixellab] {len(planned)} request(s) planned")
    for request in planned:
        size = request.payload.get("image_size", {})
        print(f"- {request.request_id}: {request.endpoint} {size.get('width', '?')}x{size.get('height', '?')} -> {request.output_dir}")


def compose_description(style: dict[str, Any], description: str) -> str:
    base = str(style.get("base_prompt", "")).strip()
    negative = str(style.get("negative_prompt", "")).strip()
    parts = [description.strip()]
    if base:
        parts.append(base)
    if negative:
        parts.append(f"Avoid: {negative}.")
    return " ".join(parts)


def strip_nulls(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: strip_nulls(child) for key, child in value.items() if child is not None}
    if isinstance(value, list):
        return [strip_nulls(child) for child in value if child is not None]
    return value


def unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    stem = path.stem
    suffix = path.suffix
    for index in range(2, 1000):
        candidate = path.with_name(f"{stem}_{index:03d}{suffix}")
        if not candidate.exists():
            return candidate
    raise PixelLabError(f"Could not find unique filename for {path}")


def safe_filename(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip())
    return value.strip("._") or "asset.png"


def slug(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_-]+", "_", value.strip().lower())
    return value.strip("_") or "asset"


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PixelLabError as exc:
        print(f"[pixellab] error: {exc}", file=sys.stderr)
        raise SystemExit(1)
