"""Registers a 2D painted sprite (cropped from real concept art) as a camera-facing
billboard prop, using the same asset-pack registration contract as create_prop.py's GLB
props. Sprite3D, not a 3D mesh — this is the DD2-style path per the 2026-08-12 decision to
stop trying to fake painterly 2D illustration with a 3D-mesh-plus-outline technique.

Usage:
    python tools/prop_pipeline/create_billboard_prop.py \
        --prop-id ancient_tree_sprite_a --category ANCIENT_TREE_BLOCKER \
        --source-image path/to/matted_sprite.png --world-height 2.6
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_PACK_PATH = REPO_ROOT / "resources" / "asset_packs" / "dark_forest_frontier_v2_asset_pack.json"

# Mirrors create_prop.py's CATEGORY_RUNTIME_FOLDER so billboards land next to their GLB
# siblings instead of introducing a second folder convention.
CATEGORY_RUNTIME_FOLDER = {
    "ANCIENT_TREE_BLOCKER": "trees",
    "TREE_BLOCKER": "trees",
    "DEAD_TREE_SPIKE": "trees",
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
}


def runtime_dir_for_category(category: str) -> Path:
    folder = CATEGORY_RUNTIME_FOLDER.get(category, "misc")
    return REPO_ROOT / "assets_game" / "props" / folder / "dark_forest_frontier_v2"


def write_billboard_scene(tscn_path: Path, texture_res_path: str, pixel_size: float, image_height_px: int) -> None:
    # Sprite3D offset is in pixels (pre pixel_size scaling); shifting the draw up by half
    # the image height puts the sprite's bottom edge at the node's local origin, matching
    # the tile_center_at_ground pivot convention used by GLB props.
    # shaded=false: scene point lights (esp. the corruption glow) wash near-black painted
    # pixels into flat pink at close range. Unshaded keeps the sprite's actual painted colors.
    offset_y = image_height_px / 2.0
    content = f"""[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="{texture_res_path}" id="1"]

[node name="Billboard" type="Sprite3D"]
texture = ExtResource("1")
pixel_size = {pixel_size:.6f}
offset = Vector2(0, {offset_y:.1f})
billboard = 2
alpha_cut = 2
shaded = false
double_sided = true
"""
    tscn_path.write_text(content, encoding="utf-8")


def register_asset(category: str, runtime_tscn: Path, replace: bool) -> None:
    res_path = "res://" + str(runtime_tscn.relative_to(REPO_ROOT)).replace("\\", "/")
    entry = {
        "path": res_path,
        "footprint": [1, 1],
        "height_offset": 0.0,
        "rotation_random": False,
        "scale_random": [0.95, 1.08],
    }
    data = json.loads(ASSET_PACK_PATH.read_text(encoding="utf-8"))
    categories = data.setdefault("asset_3d_categories", {})
    category_def = categories.setdefault(category, {"biome": "DARK_FOREST_FRONTIER_V2"})
    category_def.setdefault("biome", "DARK_FOREST_FRONTIER_V2")
    if replace:
        category_def["assets"] = [entry]
    else:
        assets = category_def.setdefault("assets", [])
        assets[:] = [asset for asset in assets if not (isinstance(asset, dict) and asset.get("path") == res_path)]
        assets.append(entry)
    ASSET_PACK_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prop-id", required=True)
    parser.add_argument("--category", required=True)
    parser.add_argument("--source-image", required=True, type=Path, help="Already-cropped/matted PNG with alpha")
    parser.add_argument("--world-height", required=True, type=float, help="Target height in Godot 3D units")
    parser.add_argument("--replace", action="store_true", help="Replace all existing assets in this category instead of adding to them")
    args = parser.parse_args()

    if not args.source_image.exists():
        raise SystemExit(f"Source image does not exist: {args.source_image}")

    img = Image.open(args.source_image).convert("RGBA")
    width_px, height_px = img.size
    pixel_size = args.world_height / height_px

    runtime_dir = runtime_dir_for_category(args.category)
    runtime_dir.mkdir(parents=True, exist_ok=True)
    texture_path = runtime_dir / f"df_v2_{args.prop_id}_a.png"
    img.save(texture_path)
    tscn_path = runtime_dir / f"df_v2_{args.prop_id}_a.tscn"
    texture_res_path = "res://" + str(texture_path.relative_to(REPO_ROOT)).replace("\\", "/")
    write_billboard_scene(tscn_path, texture_res_path, pixel_size, height_px)
    register_asset(args.category, tscn_path, args.replace)

    print(f"[done] {args.prop_id}: {width_px}x{height_px}px -> {args.world_height} world units (pixel_size={pixel_size:.6f})")
    print(f"       texture: {texture_path.relative_to(REPO_ROOT)}")
    print(f"       scene:   {tscn_path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
