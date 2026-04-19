import os
import shutil
from PIL import Image

BASE = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\kenney"
SOURCE = os.path.join(BASE, "source")
OUTPUT = os.path.join(BASE, "processed")

TILE_W = 256
TILE_H = 352

os.makedirs(OUTPUT, exist_ok=True)

categories = [
    "low_ground", "mid_ground", "high_ground", "peak",
    "cliff", "water", "economy_plot", "foliage", "corrupted"
]

total = 0

for cat in categories:
    cat_path = os.path.join(SOURCE, cat)
    if not os.path.exists(cat_path):
        print(f"  [SKIP] {cat} - folder not found")
        continue

    images = sorted([f for f in os.listdir(cat_path)
                     if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))])

    if not images:
        print(f"  [EMPTY] {cat} - no images found")
        continue

    print(f"\n  Processing {cat} ({len(images)} tiles)...")

    for i, filename in enumerate(images):
        src = os.path.join(cat_path, filename)
        dst_name = f"{cat}_v{i+1:02d}.png"
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
print(f"Output: {OUTPUT}")