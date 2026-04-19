import os, shutil, glob
from PIL import Image

# ── PATHS ──────────────────────────────────────────────────────────────────────
KENNEY_PACKS = [
    r"C:\Users\AndrewHyslop\Downloads\kenney_sketch-town\Tiles",
    r"C:\Users\AndrewHyslop\Downloads\kenney_sketch-town-expansion\Tiles",
]
BASE      = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\kenney"
SOURCE    = os.path.join(BASE, "source")
PROCESSED = os.path.join(BASE, "processed")
TILESETS  = os.path.join(BASE, "tilesets")
TRES_OUT  = os.path.join(TILESETS, "kenney_full.tres")
GD_OUT    = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\scripts\map\tile_ids.gd"
TILE_W, TILE_H, TOP_W, TOP_H = 256, 352, 256, 128
DIRS = ["N","E","S","W"]

# ── TILE CATEGORY MAP ──────────────────────────────────────────────────────────
TILE_MAP = {
    "grass_block":               "ground",
    "grass_center":              "ground",
    "grass_corner":              "ground_corner",
    "grass_slope":               "ground_slope",
    "grass_slopeConcave":        "ground_slope_concave",
    "grass_slopeConvex":         "ground_slope_convex",
    "dirt_center":               "dirt",
    "dirt_low":                  "dirt_low",
    "dirt_corner":               "dirt_corner",
    "cliff":                     "cliff_face",
    "cliff_corner":              "cliff_face_corner",
    "cliff_cornerInner":         "cliff_face_corner_inner",
    "cliff_entrance":            "cliff_entrance",
    "cliff_top":                 "cliff_top",
    "cliff_topCorner":           "cliff_top_corner",
    "cliff_topCornerInner":      "cliff_top_corner_inner",
    "cliff_topEntrance":         "cliff_top_entrance",
    "grass_water":               "water_edge",
    "grass_waterConcave":        "water_edge_concave",
    "grass_waterConvex":         "water_edge_convex",
    "grass_waterRiver":          "water_river",
    "grass_river":               "water_river_flat",
    "grass_riverBend":           "water_river_bend",
    "grass_riverCorner":         "water_river_corner",
    "grass_riverCrossing":       "water_river_crossing",
    "grass_riverEnd":            "water_river_end",
    "grass_riverEndSquare":      "water_river_end_square",
    "grass_riverSlope":          "water_river_slope",
    "grass_riverSplit":          "water_river_split",
    "grass_riverBridge":         "water_bridge",
    "water_center":              "water_deep",
    "water_fall":                "water_fall",
    "bridge":                    "bridge",
    "grass_path":                "path",
    "grass_pathBend":            "path_bend",
    "grass_pathCorner":          "path_corner",
    "grass_pathCrossing":        "path_crossing",
    "grass_pathEnd":             "path_end",
    "grass_pathEndSquare":       "path_end_square",
    "grass_pathSlope":           "path_slope",
    "grass_pathSplit":           "path_split",
    "tree_single":               "tree_single",
    "tree_multiple":             "tree_multiple",
    "tree_pine":                 "tree_pine",
    "tree_pineLarge":            "tree_pine_large",
    "rocks_grass":               "rocks_grass",
    "rocks_dirt":                "rocks_dirt",
    "furrow":                    "furrow",
    "furrow_end":                "furrow_end",
    "furrow_crop":               "furrow_crop",
    "furrow_cropWheat":          "furrow_crop_wheat",
    "building_center":           "building_center",
    "building_centerBeige":      "building_center_beige",
    "building_corner":           "building_corner",
    "building_cornerBeige":      "building_corner_beige",
    "building_door":             "building_door",
    "building_doorBeige":        "building_door_beige",
    "building_doorWindows":      "building_door_windows",
    "building_doorWindowsBeige": "building_door_windows_beige",
    "building_window":           "building_window",
    "building_windowBeige":      "building_window_beige",
    "building_windows":          "building_windows",
    "building_windowsBeige":     "building_windows_beige",
    "building_stack":            "building_stack",
    "building_stackBeige":       "building_stack_beige",
    "building_stackCorner":      "building_stack_corner",
    "building_stackCornerBeige": "building_stack_corner_beige",
    "balcony_stone":             "balcony_stone",
    "balcony_wood":              "balcony_wood",
    "castle_wall":               "castle_wall",
    "castle_center":             "castle_center",
    "castle_corner":             "castle_corner",
    "castle_bend":               "castle_bend",
    "castle_gate":               "castle_gate",
    "castle_gateOpen":           "castle_gate_open",
    "castle_slope":              "castle_slope",
    "castle_tower":              "castle_tower",
    "castle_towerBeige":         "castle_tower_beige",
    "castle_towerBeigeBase":     "castle_tower_beige_base",
    "castle_towerBeigeTop":      "castle_tower_beige_top",
    "castle_towerBrown":         "castle_tower_brown",
    "castle_towerBrownBase":     "castle_tower_brown_base",
    "castle_towerBrownTop":      "castle_tower_brown_top",
    "castle_towerGreen":         "castle_tower_green",
    "castle_towerGreenBase":     "castle_tower_green_base",
    "castle_towerGreenTop":      "castle_tower_green_top",
    "castle_towerPurple":        "castle_tower_purple",
    "castle_towerPurpleBase":    "castle_tower_purple_base",
    "castle_towerPurpleTop":     "castle_tower_purple_top",
    "castle_towerCenter":        "castle_tower_center",
    "castle_end":                "castle_end",
    "castle_endRound":           "castle_end_round",
    "castle_endRuined":          "castle_end_ruined",
    "castle_window":             "castle_window",
    "structure_arch":            "structure_arch",
    "structure_high":            "structure_high",
    "structure_low":             "structure_low",
    "fence_wood":                "fence_wood",
    "fence_woodCorner":          "fence_wood_corner",
    "fence_woodCurve":           "fence_wood_curve",
    "fence_woodEnd":             "fence_wood_end",
    "fence_woodDouble":          "fence_wood_double",
    "fence_woodDoubleCorner":    "fence_wood_double_corner",
    "fence_woodDoubleCurve":     "fence_wood_double_curve",
    "fence_woodDoubleEnd":       "fence_wood_double_end",
    "well":                      "well",
    "roof_gableBeige":           "roof_gable_beige",
    "roof_gableBrown":           "roof_gable_brown",
    "roof_gableGreen":           "roof_gable_green",
    "roof_gablePurple":          "roof_gable_purple",
    "roof_gableCornerBeige":     "roof_gable_corner_beige",
    "roof_gableCornerBrown":     "roof_gable_corner_brown",
    "roof_gableCornerGreen":     "roof_gable_corner_green",
    "roof_gableCornerPurple":    "roof_gable_corner_purple",
    "roof_pointBeige":           "roof_point_beige",
    "roof_pointBrown":           "roof_point_brown",
    "roof_pointGreen":           "roof_point_green",
    "roof_pointPurple":          "roof_point_purple",
    "roof_roundBeige":           "roof_round_beige",
    "roof_roundBrown":           "roof_round_brown",
    "roof_roundGreen":           "roof_round_green",
    "roof_roundPurple":          "roof_round_purple",
    "roof_roundCornerBeige":     "roof_round_corner_beige",
    "roof_roundCornerBrown":     "roof_round_corner_brown",
    "roof_roundCornerGreen":     "roof_round_corner_green",
    "roof_roundCornerPurple":    "roof_round_corner_purple",
    "roof_roundedBeige":         "roof_rounded_beige",
    "roof_roundedBrown":         "roof_rounded_brown",
    "roof_roundedGreen":         "roof_rounded_green",
    "roof_roundedPurple":        "roof_rounded_purple",
    "roof_slantBeige":           "roof_slant_beige",
    "roof_slantBrown":           "roof_slant_brown",
    "roof_slantGreen":           "roof_slant_green",
    "roof_slantPurple":          "roof_slant_purple",
    "roof_slantCornerBeige":     "roof_slant_corner_beige",
    "roof_slantCornerBrown":     "roof_slant_corner_brown",
    "roof_slantCornerGreen":     "roof_slant_corner_green",
    "roof_slantCornerPurple":    "roof_slant_corner_purple",
    "roof_slantCornerInnerBeige":"roof_slant_corner_inner_beige",
    "roof_slantCornerInnerBrown":"roof_slant_corner_inner_brown",
    "roof_slantCornerInnerGreen":"roof_slant_corner_inner_green",
    "roof_slantCornerInnerPurple":"roof_slant_corner_inner_purple",
    "roof_churchBeige":          "roof_church_beige",
    "roof_churchBrown":          "roof_church_brown",
    "roof_churchGreen":          "roof_church_green",
    "roof_churchPurple":         "roof_church_purple",
}

def get_type_dir(filename):
    name = filename.replace(".png","")
    parts = name.split("_")
    if parts[-1] in DIRS:
        return "_".join(parts[:-1]), parts[-1]
    return name, None

# ── STAGE 1 — SORT TILES ───────────────────────────────────────────────────────
print("\n=== STAGE 1: Sorting tiles ===")
all_cats = set(TILE_MAP.values())
for cat in all_cats:
    os.makedirs(os.path.join(SOURCE, cat), exist_ok=True)

copied = 0
for pack in KENNEY_PACKS:
    if not os.path.exists(pack):
        print(f"  PACK NOT FOUND: {pack}"); continue
    for filename in os.listdir(pack):
        if not filename.endswith(".png"): continue
        tile_type, direction = get_type_dir(filename)
        if tile_type in TILE_MAP and direction:
            cat = TILE_MAP[tile_type]
            dst = os.path.join(SOURCE, cat, filename)
            if not os.path.exists(dst):
                shutil.copy2(os.path.join(pack, filename), dst)
                copied += 1
print(f"  Sorted {copied} tiles into {len(all_cats)} categories")

# ── STAGE 2 — PROCESS TILES ────────────────────────────────────────────────────
print("\n=== STAGE 2: Processing tiles ===")
os.makedirs(PROCESSED, exist_ok=True)
for f in os.listdir(PROCESSED):
    if f.endswith(".png"): os.remove(os.path.join(PROCESSED, f))

total = 0
for cat in sorted(os.listdir(SOURCE)):
    cat_path = os.path.join(SOURCE, cat)
    if not os.path.isdir(cat_path): continue
    images = sorted([f for f in os.listdir(cat_path) if f.endswith(".png")])
    for filename in images:
        name = filename.replace(".png","")
        parts = name.split("_")
        direction = parts[-1] if parts[-1] in DIRS else "S"
        dst_name = f"{cat}_{direction}.png"
        try:
            img = Image.open(os.path.join(cat_path, filename)).convert("RGBA")
            if img.size != (TILE_W, TILE_H):
                img = img.resize((TILE_W, TILE_H), Image.LANCZOS)
            img.save(os.path.join(PROCESSED, dst_name), "PNG")
            total += 1
        except Exception as e:
            print(f"  ERROR: {filename}: {e}")
print(f"  Processed {total} tiles")

# ── STAGE 3 — GENERATE TILESET ─────────────────────────────────────────────────
print("\n=== STAGE 3: Generating TileSet ===")
os.makedirs(TILESETS, exist_ok=True)
os.makedirs(os.path.dirname(GD_OUT), exist_ok=True)

tiles = sorted(glob.glob(os.path.join(PROCESSED, "*.png")))
if not tiles:
    print("ERROR: No tiles found"); exit(1)

lines = ['[gd_resource type="TileSet" format=3]\n\n']
for i, t in enumerate(tiles):
    rel = "res://assets/tiles/kenney/processed/" + os.path.basename(t)
    lines.append(f'[ext_resource type="Texture2D" path="{rel}" id="{i+1}"]\n')
lines.append('\n')
for i, t in enumerate(tiles):
    lines.append(f'[sub_resource type="TileSetAtlasSource" id="Source_{i}"]\n')
    lines.append(f'texture = ExtResource("{i+1}")\n')
    lines.append(f'texture_region_size = Vector2i({TILE_W}, {TILE_H})\n')
    lines.append(f'0:0/0 = 0\n\n')
lines.append('[resource]\ntile_shape = 1\ntile_layout = 1\ntile_offset_axis = 0\n')
lines.append(f'tile_size = Vector2i({TOP_W}, {TOP_H})\n')
for i in range(len(tiles)):
    lines.append(f'sources/{i} = SubResource("Source_{i}")\n')

with open(TRES_OUT, "w", encoding="utf-8") as f:
    f.write("".join(lines))
print(f"  TileSet saved: {TRES_OUT}")

# Write GDScript constants
gd_lines = ["# AUTO-GENERATED — do not edit manually\n# Run run_pipeline.py to regenerate\n\nclass_name TileIDs\n\n"]
for i, t in enumerate(tiles):
    name = os.path.basename(t).replace(".png","").upper()
    gd_lines.append(f"const {name} = {i}\n")
with open(GD_OUT, "w", encoding="utf-8") as f:
    f.write("".join(gd_lines))
print(f"  tile_ids.gd saved: {GD_OUT}")

print(f"\n=== PIPELINE COMPLETE ===")
print(f"  {len(tiles)} tiles ready")
print(f"  TileSet: {TRES_OUT}")
print(f"  Load in Godot: TileMapLayer -> Tile Set -> Load -> kenney_full.tres")