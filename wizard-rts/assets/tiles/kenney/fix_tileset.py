import glob, os

BASE = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\kenney"
TILESETS = os.path.join(BASE, "tilesets")
TRES_OUT = os.path.join(TILESETS, "kenney_full.tres")
PROCESSED = os.path.join(BASE, "processed")

TILE_W, TILE_H = 256, 352
TOP_W, TOP_H = 256, 128

tiles = sorted(glob.glob(os.path.join(PROCESSED, "*.png")))
if not tiles:
    print("ERROR: No tiles found"); exit(1)

print(f"Found {len(tiles)} tiles")

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
print(f"Done. TileSet saved with tile size {TOP_W}x{TOP_H}")