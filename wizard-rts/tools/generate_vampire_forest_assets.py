from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math

ROOT = Path(__file__).resolve().parents[1]
VOXEL = ROOT / "assets" / "tiles" / "voxel"
UNITS = ROOT / "assets" / "units" / "vampire_mushroom_forest"

TILE_W, TILE_H = 111, 128
UNIT = 96
SHEET_FRAMES = 4
SHEET_ROWS = 2

PALETTE = {
    "abyss": "#0A1612",
    "damp": "#142420",
    "floor": "#1E3A2D",
    "moss": "#2D5A3E",
    "fern": "#4A8A5C",
    "spore": "#7BC47F",
    "blood_dark": "#2B0608",
    "blood": "#8B1A1F",
    "kill": "#C13030",
    "bloom": "#E85A5A",
    "pool": "#0E2C32",
    "algae": "#1A4F5C",
    "wisp": "#3FA8B5",
    "spark": "#7DDDE8",
    "bark": "#332820",
    "wood": "#5C4838",
    "bone": "#D6C7AE",
    "old_bone": "#8A7560",
}


def rgba(hex_color, alpha=255):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def ensure_dirs():
    VOXEL.mkdir(parents=True, exist_ok=True)
    UNITS.mkdir(parents=True, exist_ok=True)


def diamond_points(cx=TILE_W // 2, cy=43, rx=52, ry=29):
    return [(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)]


def draw_diamond_base(draw, base, edge, top=43):
    pts = diamond_points(cy=top)
    draw.polygon(pts, fill=rgba(base), outline=rgba(edge))
    draw.polygon([(3, top), (TILE_W // 2, top + 29), (TILE_W - 4, top), (TILE_W // 2, top + 42)], fill=rgba(edge, 130))


def add_noise(draw, colors, top=43, count=34):
    for i in range(count):
        x = 8 + (i * 29) % 96
        y = top - 22 + (i * 17) % 45
        c = colors[i % len(colors)]
        draw.rectangle((x, y, x + 2 + i % 4, y + 1), fill=rgba(c, 155))


def add_moss_threads(draw, top=43, variant=0, count=18):
    for i in range(count):
        x = 12 + (i * 23 + variant * 17) % 87
        y = top - 24 + (i * 19 + variant * 5) % 48
        length = 6 + (i + variant) % 12
        draw.line((x, y, x + length, y + 3), fill=rgba(PALETTE["spore"], 80), width=1)


def add_stone_facets(draw, top=43, variant=0):
    for i in range(9):
        x = 18 + (i * 19 + variant * 11) % 72
        y = top - 20 + (i * 13 + variant * 7) % 38
        draw.polygon(
            [(x, y), (x + 10, y + 3), (x + 5, y + 9), (x - 5, y + 5)],
            fill=rgba(PALETTE["old_bone"], 95),
        )


def tile_low(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["floor"], PALETTE["abyss"])
    add_noise(d, [PALETTE["damp"], PALETTE["moss"], PALETTE["blood_dark"]], count=46)
    add_moss_threads(d, variant=variant)
    if variant % 2 == 0:
        d.ellipse((35, 29, 45, 36), fill=rgba(PALETTE["blood"], 160))
        d.line((40, 33, 52, 39), fill=rgba(PALETTE["kill"], 130), width=1)
    img.save(path)


def tile_mid(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["moss"], PALETTE["damp"], top=38)
    d.polygon([(5, 39), (55, 69), (106, 39), (55, 83)], fill=rgba(PALETTE["abyss"], 120))
    add_noise(d, [PALETTE["floor"], PALETTE["fern"], PALETTE["blood_dark"]], top=38, count=42)
    add_stone_facets(d, top=38, variant=variant)
    if variant % 2 == 1:
        d.line((24, 27, 61, 45, 84, 35), fill=rgba(PALETTE["spore"], 95), width=2)
    img.save(path)


def tile_high(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["fern"], PALETTE["floor"], top=32)
    d.polygon([(4, 34), (55, 62), (107, 34), (55, 92)], fill=rgba(PALETTE["abyss"], 165))
    add_noise(d, [PALETTE["moss"], PALETTE["old_bone"], PALETTE["spore"]], top=32, count=34)
    add_stone_facets(d, top=32, variant=variant)
    if variant == 2:
        d.arc((32, 13, 78, 51), 20, 340, fill=rgba(PALETTE["bone"], 175), width=2)
    img.save(path)


def tile_water(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["pool"], PALETTE["abyss"], top=43)
    d.polygon(diamond_points(cy=43, rx=45, ry=24), fill=rgba(PALETTE["algae"], 165))
    for i in range(5):
        y = 28 + i * 7 + variant
        d.arc((20, y, 92, y + 24), 190, 350, fill=rgba(PALETTE["wisp"], 95), width=2)
    d.ellipse((50, 37, 59, 43), fill=rgba(PALETTE["spark"], 160))
    img.save(path)


def tile_cliff(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["abyss"], PALETTE["damp"], top=36)
    for i in range(8):
        x = 12 + i * 12 + (variant * 5) % 7
        d.polygon(
            [(x, 34), (x + 11, 38), (x + 8, 95), (x - 6, 83)],
            fill=rgba(PALETTE["bark"], 210),
            outline=rgba(PALETTE["abyss"], 160),
        )
        d.line((x + 3, 43, x - 2, 88), fill=rgba(PALETTE["old_bone"], 90), width=1)
    d.line((14, 36, 96, 35), fill=rgba(PALETTE["bone"], 110), width=2)
    img.save(path)


def tile_giant_mushroom(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["abyss"], PALETTE["damp"], top=50)
    d.rectangle((48, 34, 63, 88), fill=rgba(PALETTE["old_bone"]), outline=rgba(PALETTE["abyss"]))
    d.ellipse((16, 8, 97, 49), fill=rgba(PALETTE["blood"]), outline=rgba(PALETTE["blood_dark"]))
    d.ellipse((24, 12, 75, 32), fill=rgba(PALETTE["kill"], 190))
    for i in range(16):
        x = 25 + (i * 17 + variant * 9) % 58
        y = 14 + (i * 11) % 26
        d.ellipse((x, y, x + 4, y + 3), fill=rgba(PALETTE["bone"], 210))
    d.ellipse((48, 23, 63, 36), fill=rgba(PALETTE["spark"], 110))
    img.save(path)


def tile_economy(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["floor"], PALETTE["abyss"], top=43)
    d.ellipse((31, 22, 81, 61), fill=rgba(PALETTE["blood_dark"], 210), outline=rgba(PALETTE["old_bone"]))
    d.ellipse((39, 29, 72, 53), fill=rgba(PALETTE["blood"], 205))
    d.ellipse((49, 34, 62, 47), fill=rgba(PALETTE["spark"], 210))
    for i in range(6):
        d.line((55, 43, 26 + i * 11, 67), fill=rgba(PALETTE["spore"], 80), width=2)
    img.save(path)


def tile_ruin_floor(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["damp"], PALETTE["abyss"], top=43)
    for i in range(18):
        x = 15 + (i * 19 + variant * 13) % 78
        y = 22 + (i * 17) % 39
        d.rectangle((x, y, x + 8, y + 5), fill=rgba(PALETTE["old_bone"], 175), outline=rgba(PALETTE["abyss"], 70))
    d.arc((31, 14, 81, 64), 15, 345, fill=rgba(PALETTE["spark"], 135), width=2)
    img.save(path)


def tile_structure(path, base, trim, glow, variant, ruined=False):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["damp"], PALETTE["abyss"], top=48)
    d.rectangle((28, 23, 83, 76), fill=rgba(base), outline=rgba(PALETTE["abyss"]))
    for x in range(31, 80, 11):
        h = 11 + (x + variant) % 13
        d.rectangle((x, 23 + h, x + 5, 76), fill=rgba(trim, 210))
    d.rectangle((48, 50, 63, 76), fill=rgba(PALETTE["abyss"], 230))
    d.ellipse((51, 43, 60, 54), fill=rgba(glow, 210))
    if ruined:
        for i in range(5):
            x = 28 + (i * 13 + variant * 7) % 52
            d.line((x, 18, x + 8, 31), fill=rgba(PALETTE["blood"], 230), width=3)
        d.polygon([(28, 23), (41, 12), (52, 23)], fill=rgba(PALETTE["bark"]))
    img.save(path)


def tile_foliage(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["abyss"], PALETTE["damp"], top=49)
    for i in range(15):
        x = 18 + (i * 19 + variant * 11) % 78
        y = 18 + (i * 13) % 34
        d.line((x, 71, x + math.sin(i) * 14, y), fill=rgba(PALETTE["bark"], 220), width=3)
        d.ellipse((x - 12, y - 9, x + 14, y + 10), fill=rgba(PALETTE["blood"], 140))
    d.ellipse((48, 27, 61, 40), fill=rgba(PALETTE["bloom"], 230))
    d.ellipse((52, 31, 57, 36), fill=rgba(PALETTE["spark"], 245))
    img.save(path)


def tile_path(path, variant):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_diamond_base(d, PALETTE["floor"], PALETTE["abyss"], top=43)
    for i in range(18):
        x = 20 + (i * 17 + variant * 9) % 68
        y = 26 + (i * 11) % 32
        d.rectangle((x, y, x + 7, y + 4), fill=rgba(PALETTE["old_bone"], 175))
    d.line((24, 51, 87, 35), fill=rgba(PALETTE["bone"], 115), width=4)
    img.save(path)


def unit_shadow(d):
    d.ellipse((24, 64, 72, 82), fill=(0, 0, 0, 88))


def draw_life_wizard_frame(frame=0, row=0):
    img = Image.new("RGBA", (UNIT, UNIT), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    unit_shadow(d)
    bob = int(math.sin(frame / SHEET_FRAMES * math.tau) * (2 if row == 1 else 1))
    step = int(math.sin(frame / SHEET_FRAMES * math.tau) * 4) if row == 1 else 0
    d.polygon([(37, 29 + bob), (58, 29 + bob), (66, 71), (30, 71)], fill=rgba(PALETTE["moss"]), outline=rgba(PALETTE["abyss"]))
    d.polygon([(41, 27 + bob), (55, 27 + bob), (51, 9 + bob), (45, 9 + bob)], fill=rgba(PALETTE["blood"]), outline=rgba(PALETTE["abyss"]))
    d.ellipse((38, 23 + bob, 58, 43 + bob), fill=rgba(PALETTE["bone"]))
    d.rectangle((45, 42, 51, 70), fill=rgba(PALETTE["bark"]))
    d.line((63, 35 + bob, 78 + step, 17 + bob), fill=rgba(PALETTE["wood"]), width=4)
    d.ellipse((74 + step, 10 + bob, 86 + step, 22 + bob), fill=rgba(PALETTE["spark"], 210))
    d.ellipse((31, 39, 43, 51), fill=rgba(PALETTE["spore"], 160))
    d.ellipse((50, 30 + bob, 53, 34 + bob), fill=rgba(PALETTE["abyss"]))
    d.line((37, 68, 34 - step, 80), fill=rgba(PALETTE["abyss"]), width=3)
    d.line((58, 68, 62 + step, 80), fill=rgba(PALETTE["abyss"]), width=3)
    return img


def draw_fire_wizard_frame(frame=0, row=0):
    img = Image.new("RGBA", (UNIT, UNIT), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    unit_shadow(d)
    bob = int(math.sin(frame / SHEET_FRAMES * math.tau) * (2 if row == 1 else 1))
    step = int(math.sin(frame / SHEET_FRAMES * math.tau) * 4) if row == 1 else 0
    d.polygon([(34, 31 + bob), (61, 31 + bob), (68, 72), (28, 72)], fill=rgba("#513342"), outline=rgba(PALETTE["abyss"]))
    d.ellipse((37, 21 + bob, 59, 43 + bob), fill=rgba(PALETTE["bone"]))
    for i in range(7):
        x = 36 + i * 4
        d.line((x, 24 + bob, x - 5 + i, 13 + bob), fill=rgba("#B4664D"), width=3)
    d.line((30, 41 + bob, 17 - step, 30 + bob), fill=rgba(PALETTE["old_bone"]), width=4)
    d.line((64, 39 + bob, 78 + step, 24 + bob), fill=rgba(PALETTE["old_bone"]), width=4)
    d.ellipse((75 + step, 15 + bob, 91 + step, 31 + bob), fill=rgba(PALETTE["bloom"], 210))
    d.ellipse((79 + step, 18 + bob, 87 + step, 26 + bob), fill=rgba("#FFD58A", 230))
    d.ellipse((43, 29 + bob, 46, 33 + bob), fill=rgba(PALETTE["algae"]))
    d.ellipse((52, 29 + bob, 55, 33 + bob), fill=rgba(PALETTE["algae"]))
    d.line((38, 68, 35 - step, 80), fill=rgba(PALETTE["abyss"]), width=3)
    d.line((58, 68, 62 + step, 80), fill=rgba(PALETTE["abyss"]), width=3)
    return img


def save_sheet(path, frame_func):
    sheet = Image.new("RGBA", (UNIT * SHEET_FRAMES, UNIT * SHEET_ROWS), (0, 0, 0, 0))
    for row in range(SHEET_ROWS):
        for frame in range(SHEET_FRAMES):
            sheet.alpha_composite(frame_func(frame, row), (frame * UNIT, row * UNIT))
    sheet.save(path)
    frame_func(0, 0).save(path.with_name(path.stem.replace("_sheet", "") + ".png"))


def draw_treant():
    img = Image.new("RGBA", (UNIT, UNIT), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    unit_shadow(d)
    d.line((48, 72, 48, 30), fill=rgba(PALETTE["bark"]), width=10)
    d.line((45, 49, 25, 30), fill=rgba(PALETTE["wood"]), width=5)
    d.line((52, 47, 72, 27), fill=rgba(PALETTE["wood"]), width=5)
    for box, color in [((31, 18, 61, 50), "floor"), ((18, 22, 45, 49), "moss"), ((51, 20, 78, 49), "fern")]:
        d.ellipse(box, fill=rgba(PALETTE[color]))
    d.ellipse((42, 47, 46, 52), fill=rgba(PALETTE["spore"]))
    d.ellipse((54, 45, 58, 50), fill=rgba(PALETTE["spore"]))
    img.save(UNITS / "life_treant.png")


def draw_vampire_mushroom():
    img = Image.new("RGBA", (UNIT, UNIT), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    unit_shadow(d)
    d.rectangle((43, 43, 54, 72), fill=rgba(PALETTE["bone"]), outline=rgba(PALETTE["abyss"]))
    d.ellipse((25, 20, 73, 51), fill=rgba(PALETTE["blood"]), outline=rgba(PALETTE["abyss"]))
    d.ellipse((32, 24, 49, 35), fill=rgba(PALETTE["bloom"], 210))
    d.ellipse((57, 29, 66, 38), fill=rgba(PALETTE["kill"], 210))
    d.line((40, 64, 25, 78), fill=rgba(PALETTE["blood_dark"]), width=4)
    d.line((56, 64, 72, 78), fill=rgba(PALETTE["blood_dark"]), width=4)
    d.ellipse((45, 48, 49, 52), fill=rgba(PALETTE["spark"]))
    img.save(UNITS / "vampire_mushroom_thrall.png")


def generate_tileset():
    tiles = sorted(VOXEL.glob("*.png"))
    lines = ['[gd_resource type="TileSet" format=3 uid="uid://cgj14ge86d4v"]\n\n']
    for i, tile in enumerate(tiles):
        rel = "res://assets/tiles/voxel/" + tile.name
        lines.append(f'[ext_resource type="Texture2D" path="{rel}" id="{i + 1}"]\n')
    lines.append("\n")
    for i, _tile in enumerate(tiles):
        lines.append(f'[sub_resource type="TileSetAtlasSource" id="Source_{i}"]\n')
        lines.append(f'texture = ExtResource("{i + 1}")\n')
        lines.append("texture_region_size = Vector2i(111, 128)\n")
        lines.append("0:0/0 = 0\n\n")
    lines.append("[resource]\n")
    lines.append("tile_shape = 1\n")
    lines.append("tile_layout = 1\n")
    lines.append("tile_offset_axis = 0\n")
    lines.append("tile_size = Vector2i(111, 55)\n")
    for i in range(len(tiles)):
        lines.append(f'sources/{i} = SubResource("Source_{i}")\n')
    (VOXEL / "voxel_tileset.tres").write_text("".join(lines), encoding="utf-8")


def main():
    ensure_dirs()
    for i in range(3):
        tile_low(VOXEL / f"low_ground_vm_{i + 1:02d}.png", i)
        tile_mid(VOXEL / f"mid_ground_vm_{i + 1:02d}.png", i)
        tile_high(VOXEL / f"high_ground_vm_{i + 1:02d}.png", i)
        tile_water(VOXEL / f"water_vm_{i + 1:02d}.png", i)
        tile_cliff(VOXEL / f"cliff_vm_{i + 1:02d}.png", i)
        tile_giant_mushroom(VOXEL / f"giant_mushroom_vm_{i + 1:02d}.png", i)
        tile_economy(VOXEL / f"economy_plot_vm_{i + 1:02d}.png", i)
        tile_ruin_floor(VOXEL / f"ruin_floor_vm_{i + 1:02d}.png", i)
        tile_foliage(VOXEL / f"foliage_vm_{i + 1:02d}.png", i)
        tile_path(VOXEL / f"path_vm_{i + 1:02d}.png", i)
        tile_path(VOXEL / f"path_slope_vm_{i + 1:02d}.png", i + 3)
        tile_structure(VOXEL / f"wizard_tower_wall_vm_{i + 1:02d}.png", PALETTE["old_bone"], PALETTE["bone"], PALETTE["spark"], i)
        tile_structure(VOXEL / f"wizard_tower_floor_vm_{i + 1:02d}.png", PALETTE["floor"], PALETTE["old_bone"], PALETTE["spark"], i)
        tile_structure(VOXEL / f"bandit_wall_vm_{i + 1:02d}.png", PALETTE["bark"], PALETTE["blood"], PALETTE["bloom"], i, True)
        tile_structure(VOXEL / f"bandit_floor_vm_{i + 1:02d}.png", PALETTE["damp"], PALETTE["wood"], PALETTE["bloom"], i, True)
    save_sheet(UNITS / "life_wizard_sheet.png", draw_life_wizard_frame)
    save_sheet(UNITS / "fire_wizard_sheet.png", draw_fire_wizard_frame)
    draw_treant()
    draw_vampire_mushroom()
    generate_tileset()
    print(f"Generated vampire mushroom forest assets in {VOXEL} and {UNITS}")


if __name__ == "__main__":
    main()
