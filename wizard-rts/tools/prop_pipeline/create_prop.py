from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    yaml = None


REPO_ROOT = Path(__file__).resolve().parents[2]
MESHY_API_BASE = "https://api.meshy.ai/openapi/v2"
MESHY_API_BASE_V1 = "https://api.meshy.ai/openapi/v1"
DEFAULT_STYLE_PROFILE = REPO_ROOT / "tools" / "prop_pipeline" / "style_profiles" / "dark_forest_frontier_v2_props.json"
ASSET_PACK_PATH = REPO_ROOT / "resources" / "asset_packs" / "dark_forest_frontier_v2_asset_pack.json"
RUNTIME_ROOT = REPO_ROOT / "assets_game" / "props"
CATEGORY_RUNTIME_FOLDER = {
    "ANCIENT_TREE_BLOCKER": "trees",
    "TREE_BLOCKER": "trees",
    "DEAD_TREE_SPIKE": "trees",
    "LANTERN_TREE_BLOCKER": "trees",
    "TWISTED_ROOT_BLOCKER": "roots",
    "ROOT_WALL_BLOCKER": "roots",
    "ROOT_BLOCKER": "roots",
    "MUSHROOM_CLUSTER_SMALL": "mushrooms",
    "MUSHROOM_CLUSTER_LARGE": "mushrooms",
    "MUSHROOM_BLOCKER": "mushrooms",
    "GLOWING_MUSHROOM_RING": "mushrooms",
    "ROCK_MOSS_CLUSTER": "rocks",
    "ROCK_BLOCKER": "rocks",
    "RUINED_SHRINE": "ruins",
    "CORRUPTED_ALTAR": "ruins",
    "BROKEN_STONE_ARCH": "ruins",
    "RUIN_PROP": "ruins",
    "SHRINE_PROP": "ruins",
    "TORCH_OR_SOUL_LIGHT": "decor",
    "BONE_DECOR": "decor",
    "ROAD_EDGE_ROOTS": "decor",
    "TORCH_PROP": "decor",
    "ROAD_DECOR": "decor",
    "WATER_EDGE_DECOR": "decor",
    "BASE_PLOT_MARKER": "plot_markers",
    "CONTENT_PLOT_MARKER": "plot_markers",
    "OUTPOST_MARKER": "plot_markers",
}
TERRAIN_ROOT = REPO_ROOT / "assets_game" / "terrain"
TERRAIN_CATEGORY_FOLDER = {
    "CLIFF_SIDE": "cliffs",
    "CLIFF_CORNER": "cliffs",
    "RAMP_MESH": "ramps",
}
REQUIRED_TOP_LEVEL = {
    "prop_id",
    "display_name",
    "category",
    "biome",
    "role",
    "visual",
    "model",
    "placement",
}


class PipelineError(RuntimeError):
    pass


@dataclass
class PropImportReport:
    prop_id: str
    meshy_called: bool = False
    raw_model_path: str = ""
    processed_glb_path: str = ""
    runtime_glb_path: str = ""
    asset_pack_path: str = ""
    style_profile_path: str = ""
    generated: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def write_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.__dict__, indent=2), encoding="utf-8")


def rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def parse_simple_yaml(text: str) -> dict[str, Any]:
    root: dict[str, Any] = {}
    stack: list[tuple[int, dict[str, Any]]] = [(-1, root)]
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        line = raw_line.strip()
        if line.startswith("- ") or ":" not in line:
            continue
        key, value_text = line.split(":", 1)
        key = key.strip()
        value_text = value_text.strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1]
        if value_text == "":
            child: dict[str, Any] = {}
            parent[key] = child
            stack.append((indent, child))
        else:
            parent[key] = parse_simple_yaml_scalar(value_text)
    return root


def parse_simple_yaml_scalar(value_text: str) -> Any:
    if value_text == "true":
        return True
    if value_text == "false":
        return False
    if value_text == "[]":
        return []
    try:
        if "." in value_text:
            return float(value_text)
        return int(value_text)
    except ValueError:
        return value_text.strip('"')


def load_spec(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise PipelineError(f"Spec file does not exist: {path}")
    with path.open("r", encoding="utf-8") as handle:
        if yaml is not None:
            data = yaml.safe_load(handle) or {}
        else:
            data = parse_simple_yaml(handle.read())
    if not isinstance(data, dict):
        raise PipelineError("Prop spec must be a YAML mapping.")
    missing = sorted(REQUIRED_TOP_LEVEL.difference(data.keys()))
    if missing:
        raise PipelineError(f"Prop spec is missing required keys: {', '.join(missing)}")
    prop_id = data.get("prop_id")
    if not isinstance(prop_id, str) or not prop_id.strip():
        raise PipelineError("prop_id must be a non-empty string.")
    model = data.get("model", {})
    if model.get("generator") != "meshy":
        raise PipelineError("Only model.generator: meshy is supported.")
    if model.get("source") not in ("text_to_3d", "image_to_3d"):
        raise PipelineError("model.source must be text_to_3d or image_to_3d.")
    visual = data.get("visual", {})
    if not str(visual.get("prompt", "")).strip():
        raise PipelineError("visual.prompt must be non-empty.")
    if model.get("source") == "image_to_3d" and not str(data.get("concept_art_path", "")).strip():
        raise PipelineError("model.source: image_to_3d requires a top-level concept_art_path.")
    if int(model.get("target_polycount", 0)) <= 0:
        raise PipelineError("model.target_polycount must be a positive integer.")
    if str(data.get("biome", "")) != "dark_forest_frontier_v2":
        raise PipelineError("This first prop pipeline currently targets biome: dark_forest_frontier_v2.")
    return data


def load_environment(require_meshy: bool, dry_run: bool) -> dict[str, str]:
    env_path = REPO_ROOT / ".env"
    if env_path.exists():
        try:
            from dotenv import load_dotenv
        except ImportError as exc:
            if not dry_run:
                raise PipelineError("Missing dependency python-dotenv. Run pip install -r tools/unit_pipeline/requirements.txt") from exc
            print("[dry-run warning] python-dotenv is not installed; .env values will not be loaded.")
            load_dotenv = None
        if load_dotenv:
            load_dotenv(env_path)
    else:
        message = "Missing .env; copy .env.example to .env and fill in local paths/API key."
        if not dry_run:
            raise PipelineError(message)
        print(f"[dry-run warning] {message}")

    env = {
        "MESHY_API_KEY": os.getenv("MESHY_API_KEY", ""),
        "BLENDER_PATH": os.getenv("BLENDER_PATH", ""),
    }
    if require_meshy and not env["MESHY_API_KEY"] and not dry_run:
        raise PipelineError("Missing MESHY_API_KEY in .env.")
    if not env["BLENDER_PATH"] and not dry_run:
        raise PipelineError("Missing BLENDER_PATH in .env.")
    return env


def runtime_dir_for_category(category: str) -> Path:
    if category in TERRAIN_CATEGORY_FOLDER:
        return TERRAIN_ROOT / TERRAIN_CATEGORY_FOLDER[category] / "dark_forest_frontier_v2"
    folder = CATEGORY_RUNTIME_FOLDER.get(category, "misc")
    return RUNTIME_ROOT / folder / "dark_forest_frontier_v2"


def ensure_output_dirs(prop_id: str, category: str, dry_run: bool) -> dict[str, Path]:
    paths = {
        "raw_dir": REPO_ROOT / "art" / "generated_props" / prop_id,
        "processed_dir": REPO_ROOT / "art" / "processed_props" / prop_id,
        "runtime_dir": runtime_dir_for_category(category),
    }
    if dry_run:
        for path in paths.values():
            print(f"[dry-run] would ensure {rel(path)}")
        return paths
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    return paths


def style_profile_path(spec: dict[str, Any]) -> Path:
    profile = spec.get("visual", {}).get("style_profile", "")
    if not profile:
        return DEFAULT_STYLE_PROFILE
    path = Path(str(profile))
    return path.resolve() if path.is_absolute() else (REPO_ROOT / path).resolve()


def compact_prompt(text: str, limit: int = 600) -> str:
    prompt = " ".join(str(text).split())
    if len(prompt) <= limit:
        return prompt
    return prompt[:limit].rsplit(" ", 1)[0]


def post_meshy_text_to_3d(requests_module: Any, api_key: str, payload: dict[str, Any]) -> str:
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    response = requests_module.post(f"{MESHY_API_BASE}/text-to-3d", headers=headers, json=payload, timeout=60)
    response.raise_for_status()
    task_id = response.json().get("result")
    if not task_id:
        raise PipelineError(f"Meshy did not return a task id: {response.text}")
    return str(task_id)


def poll_meshy_text_to_3d(requests_module: Any, api_key: str, task_id: str, timeout_seconds: int) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {api_key}"}
    task_url = f"{MESHY_API_BASE}/text-to-3d/{task_id}"
    deadline = time.time() + timeout_seconds
    task: dict[str, Any] = {}
    while time.time() < deadline:
        poll = requests_module.get(task_url, headers=headers, timeout=60)
        poll.raise_for_status()
        task = poll.json()
        status = str(task.get("status", ""))
        print(f"[meshy] task {task_id} status={status} progress={task.get('progress', '?')}")
        if status == "SUCCEEDED":
            return task
        if status in {"FAILED", "EXPIRED", "CANCELED", "CANCELLED"}:
            message = task.get("task_error", {}).get("message", "")
            raise PipelineError(f"Meshy task {task_id} failed with status {status}: {message}")
        time.sleep(15)
    raise PipelineError(f"Meshy task {task_id} timeout after {timeout_seconds} seconds.")


def call_meshy(spec: dict[str, Any], api_key: str, out_dir: Path, timeout_seconds: int = 2400) -> Path:
    try:
        import requests
    except ImportError as exc:
        raise PipelineError("Missing dependency requests. Run pip install -r tools/unit_pipeline/requirements.txt") from exc

    preview_payload = {
        "mode": "preview",
        "prompt": compact_prompt(spec["visual"]["prompt"]),
        "should_remesh": True,
        "target_polycount": int(spec["model"].get("target_polycount", 3000)),
        "topology": "quad",
    }
    negative_prompt = compact_prompt(spec.get("visual", {}).get("negative_prompt", ""))
    if negative_prompt:
        preview_payload["negative_prompt"] = negative_prompt

    preview_task_id = post_meshy_text_to_3d(requests, api_key, preview_payload)
    preview_task = poll_meshy_text_to_3d(requests, api_key, preview_task_id, timeout_seconds)

    refine_payload = {
        "mode": "refine",
        "preview_task_id": preview_task_id,
        "enable_pbr": True,
    }
    refine_task_id = post_meshy_text_to_3d(requests, api_key, refine_payload)
    refine_task = poll_meshy_text_to_3d(requests, api_key, refine_task_id, timeout_seconds)

    model_url = (refine_task.get("model_urls") or {}).get("glb")
    if not model_url:
        raise PipelineError("Meshy refine task succeeded but no GLB URL was returned.")
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_path = out_dir / f"{spec['prop_id']}_raw.glb"
    model_response = requests.get(model_url, timeout=180)
    model_response.raise_for_status()
    raw_path.write_bytes(model_response.content)
    (out_dir / "meshy_preview_task.json").write_text(json.dumps(preview_task, indent=2), encoding="utf-8")
    (out_dir / "meshy_refine_task.json").write_text(json.dumps(refine_task, indent=2), encoding="utf-8")
    return raw_path


def concept_path(spec: dict[str, Any]) -> Path:
    return (REPO_ROOT / spec["concept_art_path"]).resolve()


def image_to_data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{data}"


def call_meshy_image_to_3d(spec: dict[str, Any], api_key: str, out_dir: Path, timeout_seconds: int = 1800) -> Path:
    try:
        import requests
    except ImportError as exc:
        raise PipelineError("Missing dependency requests. Run pip install -r tools/unit_pipeline/requirements.txt") from exc

    concept = concept_path(spec)
    if not concept.exists():
        raise PipelineError(f"Missing concept art: {rel(concept)}")

    payload = {
        "image_url": image_to_data_uri(concept),
        "should_remesh": True,
        "target_polycount": int(spec["model"].get("target_polycount", 6000)),
        "should_texture": True,
        "enable_pbr": True,
        "target_formats": ["glb"],
    }
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    response = requests.post(f"{MESHY_API_BASE_V1}/image-to-3d", headers=headers, json=payload, timeout=60)
    response.raise_for_status()
    task_id = response.json().get("result")
    if not task_id:
        raise PipelineError(f"Meshy did not return a task id: {response.text}")

    task_url = f"{MESHY_API_BASE_V1}/image-to-3d/{task_id}"
    deadline = time.time() + timeout_seconds
    task: dict[str, Any] = {}
    while time.time() < deadline:
        poll = requests.get(task_url, headers={"Authorization": f"Bearer {api_key}"}, timeout=60)
        poll.raise_for_status()
        task = poll.json()
        status = str(task.get("status", ""))
        print(f"[meshy] task {task_id} status={status} progress={task.get('progress', '?')}")
        if status == "SUCCEEDED":
            break
        if status in {"FAILED", "EXPIRED", "CANCELED", "CANCELLED"}:
            message = task.get("task_error", {}).get("message", "")
            raise PipelineError(f"Meshy task {task_id} failed with status {status}: {message}")
        time.sleep(15)
    else:
        raise PipelineError(f"Meshy task {task_id} timeout after {timeout_seconds} seconds.")

    model_url = (task.get("model_urls") or {}).get("glb")
    if not model_url:
        raise PipelineError("Meshy task succeeded but no GLB URL was returned.")
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_path = out_dir / f"{spec['prop_id']}_raw.glb"
    model_response = requests.get(model_url, timeout=180)
    model_response.raise_for_status()
    raw_path.write_bytes(model_response.content)
    (out_dir / "meshy_image_to_3d_task.json").write_text(json.dumps(task, indent=2), encoding="utf-8")
    return raw_path


def find_existing_model(raw_dir: Path) -> Path | None:
    for pattern in ("*.glb", "*.gltf", "*.fbx", "*.obj"):
        matches = sorted(raw_dir.glob(pattern))
        if matches:
            return matches[0]
    return None


def run_blender(env: dict[str, str], spec: dict[str, Any], raw_model: Path, processed_glb: Path, dry_run: bool) -> None:
    script = Path("tools") / "prop_pipeline" / "blender_process_prop.py"
    script_args = [
        "--prop-id",
        spec["prop_id"],
        "--category",
        spec["category"],
        "--input-model",
        str(raw_model),
        "--output-glb",
        str(processed_glb),
        "--scale-meters",
        str(spec["model"].get("scale_meters", 1.0)),
        "--target-polycount",
        str(spec["model"].get("target_polycount", 3000)),
        "--pivot",
        str(spec.get("placement", {}).get("pivot", "tile_center_at_ground")),
        "--style-profile",
        str(style_profile_path(spec)),
    ]
    material_override = str(spec.get("visual", {}).get("material", ""))
    if material_override:
        script_args.extend(["--material-override", material_override])
    bootstrap = (
        "import runpy, sys; "
        f"sys.argv = {[str(script), *script_args]!r}; "
        f"runpy.run_path({str(script)!r}, run_name='__main__')"
    )
    command = [env["BLENDER_PATH"], "--background", "--python-expr", bootstrap]
    if dry_run:
        print("[dry-run] would run Blender:")
        print(" ".join(f'"{part}"' if " " in part else part for part in command))
        return
    result = subprocess.run(command, cwd=REPO_ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        raise PipelineError(f"Blender export failure:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")


def runtime_asset_name(prop_id: str) -> str:
    return f"df_v2_{prop_id}_a.glb"


def copy_runtime_asset(processed_glb: Path, prop_id: str, category: str, dry_run: bool) -> Path:
    runtime_path = runtime_dir_for_category(category) / runtime_asset_name(prop_id)
    if dry_run:
        print(f"[dry-run] would copy {rel(processed_glb)} to {rel(runtime_path)}")
        return runtime_path
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(processed_glb, runtime_path)
    return runtime_path


def register_prop_asset(spec: dict[str, Any], runtime_path: Path, dry_run: bool) -> None:
    category = str(spec["category"])
    res_path = "res://" + rel(runtime_path)
    entry = {
        "path": res_path,
        "footprint": [1, 1],
        "height_offset": float(spec.get("placement", {}).get("height_offset", 0.0)),
        "rotation_random": True,
        "scale_random": [0.98, 1.04],
    }
    if dry_run:
        print(f"[dry-run] would register {category}: {json.dumps(entry)}")
        return
    data = json.loads(ASSET_PACK_PATH.read_text(encoding="utf-8"))
    categories = data.setdefault("asset_3d_categories", {})
    category_def = categories.setdefault(category, {"biome": "DARK_FOREST_FRONTIER_V2"})
    category_def.setdefault("biome", "DARK_FOREST_FRONTIER_V2")
    assets = category_def.setdefault("assets", [])
    assets[:] = [asset for asset in assets if not (isinstance(asset, dict) and asset.get("path") == res_path)]
    assets.append(entry)
    ASSET_PACK_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a static terrain/prop GLB from a YAML text-to-3D or image-to-3D spec.")
    parser.add_argument("spec", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-meshy", action="store_true")
    args = parser.parse_args()

    spec_path = (REPO_ROOT / args.spec).resolve() if not args.spec.is_absolute() else args.spec.resolve()
    report = PropImportReport(prop_id="unknown")
    try:
        spec = load_spec(spec_path)
        prop_id = spec["prop_id"]
        report.prop_id = prop_id
        category = str(spec["category"])
        env = load_environment(require_meshy=not args.skip_meshy, dry_run=args.dry_run)
        paths = ensure_output_dirs(prop_id, category, args.dry_run)
        profile_path = style_profile_path(spec)
        report.style_profile_path = rel(profile_path)
        if not profile_path.exists():
            raise PipelineError(f"Missing style profile: {rel(profile_path)}")
        processed_glb = paths["processed_dir"] / f"{prop_id}.glb"
        report.processed_glb_path = rel(processed_glb)
        report.asset_pack_path = rel(ASSET_PACK_PATH)

        raw_model = find_existing_model(paths["raw_dir"]) if args.skip_meshy or args.dry_run else None
        if args.skip_meshy:
            if raw_model is None:
                raise PipelineError(f"--skip-meshy requested but no model exists in {rel(paths['raw_dir'])}")
            report.meshy_called = False
        elif args.dry_run:
            report.meshy_called = True
            raw_model = paths["raw_dir"] / f"{prop_id}_raw.glb"
            source = spec["model"].get("source")
            verb = "Image to 3D" if source == "image_to_3d" else "Text to 3D preview/refine"
            print(f"[dry-run] would call Meshy {verb} and save {rel(raw_model)}")
        else:
            report.meshy_called = True
            if spec["model"].get("source") == "image_to_3d":
                raw_model = call_meshy_image_to_3d(spec, env["MESHY_API_KEY"], paths["raw_dir"])
            else:
                raw_model = call_meshy(spec, env["MESHY_API_KEY"], paths["raw_dir"])

        if raw_model is None:
            raise PipelineError("No raw model path was resolved.")
        report.raw_model_path = rel(raw_model)

        run_blender(env, spec, raw_model, processed_glb, args.dry_run)
        runtime_glb = copy_runtime_asset(processed_glb, prop_id, category, args.dry_run)
        report.runtime_glb_path = rel(runtime_glb)
        register_prop_asset(spec, runtime_glb, args.dry_run)
        report.generated.extend([report.raw_model_path, report.processed_glb_path, report.runtime_glb_path, report.asset_pack_path])
        if not args.dry_run:
            report.write_json(paths["processed_dir"] / "pipeline_report.json")
            print(f"[done] created generated prop pipeline outputs for {prop_id}")
        else:
            print("[dry-run] validation complete; no Meshy/Blender/registry writes were performed.")
        return 0
    except Exception as exc:
        report.errors.append(str(exc))
        if report.prop_id != "unknown":
            try:
                report.write_json(REPO_ROOT / "art" / "processed_props" / report.prop_id / "pipeline_report.json")
            except Exception:
                pass
        print(f"[error] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
