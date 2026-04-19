import os
import glob

BASE = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\kenney"
PROCESSED = os.path.join(BASE, "processed")
TILESETS = os.path.join(BASE, "tilesets")
OUTPUT = os.path.join(TILESETS, "sunken_grove.tres")

TILE_W = 256
TILE_H = 352
TOP_W = 256
TOP_H = 128

os.makedirs(TILESETS, exist_ok=True)

tiles = sorted(glob.glob(os.path.join(PROCESSED, "*.png")))

if not tiles:
    print("ERROR: No processed tiles found in", PROCESSED)
    exit(1)

print(f"Found {len(tiles)} tiles")

lines = []
lines.append('[gd_resource type="TileSet" format=3]\n\n')

for i, tile_path in enumerate(tiles):
    rel_path = "res://assets/tiles/kenney/processed/" + os.path.basename(tile_path)
    lines.append(f'[ext_resource type="Texture2D" path="{rel_path}" id="{i+1}"]\n')

lines.append('\n')

for i, tile_path in enumerate(tiles):
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

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write("".join(lines))

print(f"TileSet saved: {OUTPUT}")
print(f"Sources: {len(tiles)}")