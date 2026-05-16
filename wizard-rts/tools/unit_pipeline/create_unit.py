from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
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
MESHY_API_BASE = "https://api.meshy.ai/openapi/v1"
REQUIRED_TOP_LEVEL = {
    "unit_id",
    "display_name",
    "faction",
    "role",
    "concept_art_path",
    "visual",
    "model",
    "movement",
    "stats",
    "combat",
    "animations",
    "vfx",
    "abilities",
}


class PipelineError(RuntimeError):
    pass


@dataclass
class ImportReport:
    unit_id: str
    meshy_called: bool = False
    raw_model_path: str = ""
    processed_glb_path: str = ""
    godot_scene_path: str = ""
    generated: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    manual_todos: list[str] = field(default_factory=list)
    animation_status: dict[str, str] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)

    def write_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.__dict__, indent=2), encoding="utf-8")


def rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def load_spec(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise PipelineError(f"Spec file does not exist: {path}")
    with path.open("r", encoding="utf-8") as handle:
        if yaml is not None:
            data = yaml.safe_load(handle) or {}
        else:
            data = parse_simple_yaml(handle.read())
    if not isinstance(data, dict):
        raise PipelineError("Unit spec must be a YAML mapping.")
    missing = sorted(REQUIRED_TOP_LEVEL.difference(data.keys()))
    if missing:
        raise PipelineError(f"Unit spec is missing required keys: {', '.join(missing)}")
    unit_id = data.get("unit_id")
    if not isinstance(unit_id, str) or not unit_id.strip():
        raise PipelineError("unit_id must be a non-empty string.")
    model = data.get("model", {})
    if model.get("generator") != "meshy":
        raise PipelineError("Only model.generator: meshy is supported by this first pipeline.")
    if model.get("source") != "image_to_3d":
        raise PipelineError("Only model.source: image_to_3d is supported by this first pipeline.")
    if data.get("combat", {}).get("attack_type") not in ["melee", "projectile"]:
        raise PipelineError("combat.attack_type must be melee or projectile.")
    return data


def parse_simple_yaml(text: str) -> dict[str, Any]:
    root: dict[str, Any] = {}
    stack: list[tuple[int, dict[str, Any]]] = [(-1, root)]
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        line = raw_line.strip()
        if line.startswith("- "):
            continue
        if ":" not in line:
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
        "GODOT_PATH": os.getenv("GODOT_PATH", ""),
    }
    if require_meshy and not env["MESHY_API_KEY"] and not dry_run:
        raise PipelineError("Missing MESHY_API_KEY in .env.")
    if not env["BLENDER_PATH"] and not dry_run:
        raise PipelineError("Missing BLENDER_PATH in .env.")
    if not env["GODOT_PATH"] and not dry_run:
        raise PipelineError("Missing GODOT_PATH in .env.")
    return env


def ensure_output_dirs(unit_id: str, dry_run: bool) -> dict[str, Path]:
    paths = {
        "raw_dir": REPO_ROOT / "art" / "generated_models" / unit_id,
        "processed_dir": REPO_ROOT / "art" / "processed_models" / unit_id,
        "unit_dir": REPO_ROOT / "game" / "units" / "generated" / unit_id,
        "projectiles_dir": REPO_ROOT / "game" / "projectiles" / "generated",
        "vfx_dir": REPO_ROOT / "game" / "vfx" / "generated",
        "data_dir": REPO_ROOT / "game" / "data" / "units",
    }
    if dry_run:
        for path in paths.values():
            print(f"[dry-run] would ensure {rel(path)}")
        return paths
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    return paths


def concept_path(spec: dict[str, Any]) -> Path:
    return (REPO_ROOT / spec["concept_art_path"]).resolve()


def image_to_data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{data}"


def call_meshy(spec: dict[str, Any], api_key: str, out_dir: Path, timeout_seconds: int = 1800) -> Path:
    try:
        import requests
    except ImportError as exc:
        raise PipelineError("Missing dependency requests. Run pip install -r tools/unit_pipeline/requirements.txt") from exc
    image_uri = image_to_data_uri(concept_path(spec))
    payload = {
        "image_url": image_uri,
        "should_remesh": True,
        "target_polycount": int(spec["model"].get("target_polycount", 6000)),
        "should_texture": True,
        "enable_pbr": True,
        "pose_mode": "a-pose",
        "target_formats": ["glb"],
    }
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    response = requests.post(f"{MESHY_API_BASE}/image-to-3d", headers=headers, json=payload, timeout=60)
    response.raise_for_status()
    task_id = response.json().get("result")
    if not task_id:
        raise PipelineError(f"Meshy did not return a task id: {response.text}")

    task_url = f"{MESHY_API_BASE}/image-to-3d/{task_id}"
    deadline = time.time() + timeout_seconds
    task: dict[str, Any] = {}
    while time.time() < deadline:
        poll = requests.get(task_url, headers={"Authorization": f"Bearer {api_key}"}, timeout=60)
        poll.raise_for_status()
        task = poll.json()
        status = task.get("status", "")
        print(f"[meshy] task {task_id} status={status} progress={task.get('progress', '?')}")
        if status == "SUCCEEDED":
            break
        if status in {"FAILED", "EXPIRED", "CANCELED", "CANCELLED"}:
            message = task.get("task_error", {}).get("message", "")
            raise PipelineError(f"Meshy task failed with status {status}: {message}")
        time.sleep(15)
    else:
        raise PipelineError(f"Meshy task timeout after {timeout_seconds} seconds.")

    model_url = (task.get("model_urls") or {}).get("glb")
    if not model_url:
        raise PipelineError("Meshy task succeeded but no GLB URL was returned.")
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_path = out_dir / f"{spec['unit_id']}_raw.glb"
    model_response = requests.get(model_url, timeout=180)
    model_response.raise_for_status()
    raw_path.write_bytes(model_response.content)
    (out_dir / "meshy_task.json").write_text(json.dumps(task, indent=2), encoding="utf-8")
    return raw_path


def find_existing_model(raw_dir: Path) -> Path | None:
    for pattern in ("*.glb", "*.gltf", "*.fbx", "*.obj"):
        matches = sorted(raw_dir.glob(pattern))
        if matches:
            return matches[0]
    return None


def run_blender(env: dict[str, str], spec: dict[str, Any], raw_model: Path, processed_glb: Path, dry_run: bool) -> None:
    script = Path("tools") / "unit_pipeline" / "blender_process_unit.py"
    script_args = [
        "--unit-id",
        spec["unit_id"],
        "--input-model",
        str(raw_model),
        "--output-glb",
        str(processed_glb),
        "--scale-meters",
        str(spec["model"].get("scale_meters", 1.8)),
    ]
    bootstrap = (
        "import runpy, sys; "
        f"sys.argv = {[str(script), *script_args]!r}; "
        f"runpy.run_path({str(script)!r}, run_name='__main__')"
    )
    command = [
        env["BLENDER_PATH"],
        "--background",
        "--python-expr",
        bootstrap,
    ]
    if dry_run:
        print("[dry-run] would run Blender:")
        print(" ".join(f'"{part}"' if " " in part else part for part in command))
        return
    result = subprocess.run(command, cwd=REPO_ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        raise PipelineError(f"Blender export failure:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")


def run_godot(env: dict[str, str], spec_path: Path, processed_glb: Path, force: bool, dry_run: bool, report: ImportReport) -> None:
    report_path = REPO_ROOT / "game" / "units" / "generated" / report.unit_id / "pipeline_report.json"
    script = REPO_ROOT / "tools" / "unit_pipeline" / "godot_create_unit_scene.gd"
    command = [
        env["GODOT_PATH"],
        "--headless",
        "--path",
        str(REPO_ROOT),
        "--script",
        str(script),
        "--",
        "--spec",
        str(spec_path),
        "--processed-glb",
        str(processed_glb),
        "--report-json",
        str(report_path),
    ]
    if force:
        command.append("--force")
    if dry_run:
        print("[dry-run] would run Godot:")
        print(" ".join(f'"{part}"' if " " in part else part for part in command))
        return
    report.write_json(report_path)
    result = subprocess.run(command, cwd=REPO_ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        raise PipelineError(f"Godot scene creation failure:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a first-pass Godot RTS unit from YAML and concept art.")
    parser.add_argument("spec", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-meshy", action="store_true")
    args = parser.parse_args()

    spec_path = (REPO_ROOT / args.spec).resolve() if not args.spec.is_absolute() else args.spec.resolve()
    report = ImportReport(unit_id="unknown")
    try:
        spec = load_spec(spec_path)
        unit_id = spec["unit_id"]
        report.unit_id = unit_id
        env = load_environment(require_meshy=not args.skip_meshy, dry_run=args.dry_run)
        paths = ensure_output_dirs(unit_id, dry_run=args.dry_run)
        processed_glb = paths["processed_dir"] / f"{unit_id}.glb"
        report.processed_glb_path = rel(processed_glb)
        report.godot_scene_path = f"game/units/generated/{unit_id}/{unit_id}.tscn"
        report.animation_status = {name: "placeholder requested" for name in spec.get("animations", {}).keys()}
        report.manual_todos.extend([
            "Review Meshy topology and silhouette in Blender.",
            "Replace placeholder animations with authored locomotion/combat/death clips.",
            "Hook generated Node3D unit into the active 2D RTS runtime if/when the project moves to 3D unit actors.",
        ])

        concept = concept_path(spec)
        if not concept.exists():
            message = f"Missing concept art: {rel(concept)}"
            report.warnings.append(message)
            if not args.dry_run:
                raise PipelineError(message)
            print(f"[dry-run warning] {message}")

        raw_model = find_existing_model(paths["raw_dir"]) if args.skip_meshy or args.dry_run else None
        if args.skip_meshy:
            if raw_model is None:
                raise PipelineError(f"--skip-meshy requested but no model exists in {rel(paths['raw_dir'])}")
            report.meshy_called = False
        elif args.dry_run:
            report.meshy_called = True
            raw_model = paths["raw_dir"] / f"{unit_id}_raw.glb"
            print(f"[dry-run] would call Meshy Image to 3D and save {rel(raw_model)}")
        else:
            report.meshy_called = True
            raw_model = call_meshy(spec, env["MESHY_API_KEY"], paths["raw_dir"])

        if raw_model is None:
            raise PipelineError("No raw model path was resolved.")
        report.raw_model_path = rel(raw_model)

        run_blender(env, spec, raw_model, processed_glb, dry_run=args.dry_run)
        run_godot(env, spec_path, processed_glb, args.force, args.dry_run, report)

        if args.dry_run:
            print("[dry-run] validation complete; no Blender/Godot generation was performed.")
        else:
            print(f"[done] created generated unit pipeline outputs for {unit_id}")
        return 0
    except Exception as exc:
        report.errors.append(str(exc))
        if report.unit_id != "unknown":
            report_path = REPO_ROOT / "game" / "units" / "generated" / report.unit_id / "pipeline_report.json"
            try:
                report.write_json(report_path)
            except Exception:
                pass
        print(f"[error] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
