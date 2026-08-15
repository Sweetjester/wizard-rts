"""Removes old tools/blender/create_dark_forest_v2_assets.py-sourced entries from
asset_3d_categories, leaving only assets that trace back to a props/specs/*.yaml spec
(the new Meshy+Blender pipeline). Refuses to empty a category with no new-pipeline
replacement, so a bad run can't leave a category with zero registered assets.

Usage:
    python tools/prop_pipeline/purge_procedural_assets.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_PACK_PATH = REPO_ROOT / "resources" / "asset_packs" / "dark_forest_frontier_v2_asset_pack.json"
SPECS_DIR = REPO_ROOT / "props" / "specs"


def asset_id_from_path(res_path: str) -> str:
    name = res_path.rsplit("/", 1)[-1]
    name = name.rsplit(".", 1)[0]
    if name.startswith("df_v2_"):
        name = name[len("df_v2_"):]
    for suffix in ("_a", "_b", "_c"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    known_spec_ids = {p.stem for p in SPECS_DIR.glob("*.yaml")}
    data = json.loads(ASSET_PACK_PATH.read_text(encoding="utf-8"))
    categories = data.get("asset_3d_categories", {})

    total_removed = 0
    skipped_categories = []
    for category, cat_def in categories.items():
        assets = cat_def.get("assets", [])
        new_pipeline = [a for a in assets if asset_id_from_path(a.get("path", "")) in known_spec_ids]
        procedural = [a for a in assets if asset_id_from_path(a.get("path", "")) not in known_spec_ids]
        if not procedural:
            continue
        if not new_pipeline:
            skipped_categories.append(category)
            continue
        print(f"{category}: removing {len(procedural)} procedural, keeping {len(new_pipeline)} new-pipeline")
        for a in procedural:
            print(f"    - {a.get('path')}")
        total_removed += len(procedural)
        if not args.dry_run:
            cat_def["assets"] = new_pipeline

    if skipped_categories:
        print("\nSkipped (no new-pipeline replacement yet, left procedural assets in place):")
        for category in skipped_categories:
            print(f"  - {category}")

    if args.dry_run:
        print(f"\n[dry-run] would remove {total_removed} procedural asset(s) total.")
        return 0

    ASSET_PACK_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"\nRemoved {total_removed} procedural asset(s). Asset pack updated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
