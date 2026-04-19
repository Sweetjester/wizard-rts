import os, shutil, glob

KENNEY_SRC = r"C:\Users\AndrewHyslop\Downloads\kenney_isometric-blocks\PNG\Voxel tiles"
PROJECT    = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts"
OUT_DIR    = os.path.join(PROJECT, "assets", "tiles", "voxel")
TRES_OUT   = os.path.join(OUT_DIR, "voxel_tileset.tres")

os.makedirs(OUT_DIR, exist_ok=True)

TERRAIN_TILES = {
    "low_ground":   [3, 5, 10, 16, 23, 54, 55],
    "mid_ground":   [9, 17, 19, 29, 31, 32],
    "high_ground":  [1, 12, 15, 20, 25],
    "water":        [2, 6, 7, 13, 21, 24],
    "foliage":      [30, 50, 51, 52],
    "economy_plot": [4, 11, 14, 28, 53],
    "corrupted":    [8, 22, 37, 38, 39],
    "decoration":   [18,33,34,35,36,40,41,42,43,44,45,46,47,48,49],
}

TILE_W, TILE_H = 111, 128
TOP_W,  TOP_H  = 111, 55

print("=== Stage 1: Copying tiles ===")
copied = 0
for terrain, nums in TERRAIN_TILES.items():
    for num in nums:
        src = os.path.join(KENNEY_SRC, f"voxelTile_{num:02d}.png")
        dst = os.path.join(OUT_DIR, f"{terrain}_{num:02d}.png")
        if os.path.exists(src):
            shutil.copy2(src, dst)
            copied += 1
        else:
            print(f"  MISSING: voxelTile_{num:02d}.png")
print(f"Copied {copied} tiles")

print("\n=== Stage 2: Generating TileSet ===")
tiles = sorted(glob.glob(os.path.join(OUT_DIR, "*.png")))

lines = ['[gd_resource type="TileSet" format=3]\n\n']
for i, t in enumerate(tiles):
    rel = "res://assets/tiles/voxel/" + os.path.basename(t)
    lines.append(f'[ext_resource type="Texture2D" path="{rel}" id="{i+1}"]\n')
lines.append('\n')
for i, t in enumerate(tiles):
    lines.append(f'[sub_resource type="TileSetAtlasSource" id="Source_{i}"]\n')
    lines.append(f'texture = ExtResource("{i+1}")\n')
    lines.append(f'texture_region_size = Vector2i({TILE_W}, {TILE_H})\n')
    lines.append(f'0:0/0 = 0\n\n')
lines.append('[resource]\n')
lines.append('tile_shape = 1\n')
lines.append('tile_layout = 1\n')
lines.append('tile_offset_axis = 0\n')
lines.append(f'tile_size = Vector2i({TOP_W}, {TOP_H})\n')
for i in range(len(tiles)):
    lines.append(f'sources/{i} = SubResource("Source_{i}")\n')

with open(TRES_OUT, "w", encoding="utf-8") as f:
    f.write("".join(lines))

print(f"TileSet saved: {TRES_OUT}")
print(f"Sources: {len(tiles)}")
print(f"Tile size: {TOP_W}x{TOP_H}")
print("\nID mapping:")
for i, t in enumerate(tiles):
    print(f"  {i} = {os.path.basename(t)}")
print("\nDone.")