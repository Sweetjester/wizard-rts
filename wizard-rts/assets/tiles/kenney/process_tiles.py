import os
from PIL import Image

BASE = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\kenney"
SOURCE = os.path.join(BASE, "source")
OUTPUT = os.path.join(BASE, "processed")
TILE_W, TILE_H = 256, 352

os.makedirs(OUTPUT, exist_ok=True)

# Clear old processed tiles
for f in os.listdir(OUTPUT):
    if f.endswith(".png"):
        os.remove(os.path.join(OUTPUT, f))
print("Cleared old tiles")

categories = [
    "ground", "cliff_face", "cliff_top", "cliff_corner",
    "cliff_corner_inner", "water_river", "water_curve",
    "crop", "tree_small", "tree_large", "dirt"
]

total = 0
for cat in categories:
    cat_path = os.path.join(SOURCE, cat)
    if not os.path.exists(cat_path):
        print(f"  [SKIP] {cat}")
        continue
    images = sorted([f for f in os.listdir(cat_path) if f.lower().endswith(".png")])
    if not images:
        print(f"  [EMPTY] {cat}")
        continue
    print(f"\n  {cat} ({len(images)} tiles)...")
    for filename in images:
        src = os.path.join(cat_path, filename)
        # Extract direction from filename e.g. cliff_top_E.png -> E
        name = filename.replace(".png","")
        parts = name.split("_")
        direction = parts[-1] if parts[-1] in ["N","E","S","W"] else "S"
        dst_name = f"{cat}_{direction}.png"
        dst = os.path.join(OUTPUT, dst_name)
        try:
            img = Image.open(src).convert("RGBA")
            if img.size != (TILE_W, TILE_H):
                img = img.resize((TILE_W, TILE_H), Image.LANCZOS)
            img.save(dst, "PNG")
            print(f"    Saved {dst_name}")
            total += 1
        except Exception as e:
            print(f"    ERROR: {filename}: {e}")

print(f"\nDone. {total} tiles processed.")