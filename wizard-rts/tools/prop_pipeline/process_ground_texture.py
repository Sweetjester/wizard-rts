from __future__ import annotations

"""Turn a source concept-art texture into a game-ready tileable ground albedo texture.

Applies an offset-and-feather seam pass (classic "make seamless" technique: wrap the
image by half its size, then blend a cross-shaped seam so the tile edges match) and
writes one or two tinted variants for use as StandardMaterial3D albedo textures.

Usage:
    python tools/prop_pipeline/process_ground_texture.py <source.png> <output_dir> <name_prefix> [x0,y0,x1,y1]

An optional crop box selects a sub-region of the source before the seamless pass —
useful when the source texture bakes in large focal illustrations (e.g. big mushroom
caps) that would look wrong repeated once per gameplay tile; crop down to the finer
floor detail instead.
"""

import sys
from pathlib import Path

from PIL import Image, ImageEnhance


def make_seamless(image: Image.Image, blend_fraction: float = 0.12) -> Image.Image:
    width, height = image.size
    wrapped = Image.new(image.mode, image.size)
    half_w, half_h = width // 2, height // 2
    wrapped.paste(image.crop((half_w, half_h, width, height)), (0, 0))
    wrapped.paste(image.crop((0, half_h, half_w, height)), (half_w, 0))
    wrapped.paste(image.crop((half_w, 0, width, half_h)), (0, half_h))
    wrapped.paste(image.crop((0, 0, half_w, half_h)), (half_w, half_h))

    blend_w = max(2, int(width * blend_fraction))
    blend_h = max(2, int(height * blend_fraction))
    result = wrapped.copy()

    # Feather-blend a vertical strip across the new seam at x = half_w and horizontal at y = half_h.
    for x in range(width):
        dist = abs(x - half_w)
        if dist > blend_w:
            continue
        alpha = 0.5 * (1.0 - dist / blend_w)
        src_x = (x + half_w) % width
        column_a = wrapped.crop((x, 0, x + 1, height))
        column_b = wrapped.crop((src_x, 0, src_x + 1, height))
        blended = Image.blend(column_a, column_b, alpha)
        result.paste(blended, (x, 0))

    for y in range(height):
        dist = abs(y - half_h)
        if dist > blend_h:
            continue
        alpha = 0.5 * (1.0 - dist / blend_h)
        src_y = (y + half_h) % height
        row_a = result.crop((0, y, width, y + 1))
        row_b = result.crop((0, src_y, width, src_y + 1))
        blended = Image.blend(row_a, row_b, alpha)
        result.paste(blended, (0, y))

    return result


def tinted(image: Image.Image, brightness: float, saturation: float) -> Image.Image:
    out = ImageEnhance.Brightness(image).enhance(brightness)
    out = ImageEnhance.Color(out).enhance(saturation)
    return out


def main() -> int:
    if len(sys.argv) not in (4, 5):
        print("usage: process_ground_texture.py <source.png> <output_dir> <name_prefix> [x0,y0,x1,y1]")
        return 1
    source_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    prefix = sys.argv[3]
    output_dir.mkdir(parents=True, exist_ok=True)

    source = Image.open(source_path).convert("RGB")
    if len(sys.argv) == 5:
        x0, y0, x1, y1 = (int(part) for part in sys.argv[4].split(","))
        source = source.crop((x0, y0, x1, y1)).resize((1024, 1024), Image.LANCZOS)
    seamless = make_seamless(source)

    low_path = output_dir / f"{prefix}_low_a.png"
    high_path = output_dir / f"{prefix}_high_a.png"

    tinted(seamless, brightness=0.92, saturation=0.95).save(low_path)
    tinted(seamless, brightness=1.28, saturation=1.05).save(high_path)

    print(f"[done] wrote {low_path}")
    print(f"[done] wrote {high_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
