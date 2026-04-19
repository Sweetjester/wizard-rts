from PIL import Image, ImageDraw
import os, glob
import numpy as np

BASE   = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\raw"
OUTPUT = r"C:\Users\AndrewHyslop\Documents\GitHub\wizard-rts\wizard-rts\assets\tiles\processed"

TILE_SIZES = {
    "cliff": (128, 128),
    "foliage": (128, 128),
}
DEFAULT_SIZE = (256, 128)

os.makedirs(OUTPUT, exist_ok=True)

def make_diamond_mask(w, h):
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([(w//2,0),(w-1,h//2),(w//2,h-1),(0,h//2)], fill=255)
    return mask

def process_tile(path, out_name, final_w, final_h):
    work_w = final_w * 4
    work_h = final_h * 4
    img = Image.open(path).convert("RGBA")
    img = img.resize((work_w, work_h), Image.LANCZOS)
    mask = make_diamond_mask(work_w, work_h)
    r,g,b,a = img.split()
    new_a = Image.fromarray(np.minimum(np.array(a), np.array(mask)))
    img = Image.merge("RGBA",(r,g,b,new_a))
    img = img.resize((final_w, final_h), Image.LANCZOS)
    out_path = os.path.join(OUTPUT, out_name)
    img.save(out_path, "PNG")
    print(f"  saved {out_name}")

tile_folders = [f for f in os.listdir(BASE) if os.path.isdir(os.path.join(BASE, f))]

for folder in sorted(tile_folders):
    folder_path = os.path.join(BASE, folder)
    images = sorted([f for f in os.listdir(folder_path) 
                     if f.lower().endswith((".png",".jpg",".jpeg",".webp"))])
    final_w, final_h = TILE_SIZES.get(folder, DEFAULT_SIZE)
    for i, filename in enumerate(images):
        in_path = os.path.join(folder_path, filename)
        out_name = f"forest_{folder}_v{i+1}.png"
        print(f"Processing {folder} v{i+1}...")
        process_tile(in_path, out_name, final_w, final_h)

print("\nDone. Tiles saved to:", OUTPUT)
