"""
Generate DARK_FOREST_FRONTIER replacement GLBs for all major 3D categories.

Run:
    blender --background --python tools/blender/create_dark_forest_asset_replacement_pack.py
"""

from __future__ import annotations

from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets_game" / "source" / "blender" / "dark_forest_replacement"


def out(*parts: str) -> Path:
    path = ROOT.joinpath(*parts)
    path.mkdir(parents=True, exist_ok=True)
    return path


DIRS = {
    "cliffs": out("assets_game", "terrain", "cliffs", "dark_forest_frontier"),
    "ramps": out("assets_game", "terrain", "ramps", "dark_forest_frontier"),
    "trees": out("assets_game", "props", "trees", "dark_forest_frontier"),
    "rocks": out("assets_game", "props", "rocks", "dark_forest_frontier"),
    "mushrooms": out("assets_game", "props", "mushrooms", "dark_forest_frontier"),
    "roots": out("assets_game", "props", "roots", "dark_forest_frontier"),
    "ruins": out("assets_game", "props", "ruins", "dark_forest_frontier"),
    "decor": out("assets_game", "props", "decor", "dark_forest_frontier"),
}
SRC.mkdir(parents=True, exist_ok=True)


def clear() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.92
        if emission > 0 and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = color
    return m


M = {}


def mats():
    global M
    M = {
        "rock": mat("dark_rock", (0.08, 0.09, 0.09, 1)),
        "dirt": mat("muddy_dirt", (0.32, 0.18, 0.09, 1)),
        "wood": mat("dead_wood", (0.19, 0.11, 0.06, 1)),
        "moss": mat("dark_moss", (0.04, 0.16, 0.07, 1)),
        "fungus": mat("dark_fungus", (0.25, 0.10, 0.32, 1)),
        "glow": mat("dim_torch_glow", (1.0, 0.34, 0.10, 1), 0.8),
    }


def cube(name, loc, scale, material, rz=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, rz))
    o = bpy.context.object
    o.name = name
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return o


def ico(name, loc, radius, scale, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return o


def cone(name, loc, r1, r2, depth, material, vertices=6, rz=0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=(0, 0, rz))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    return o


def ramp_mesh(name, wide=False):
    width = 1.7 if wide else 1.0
    x = width * 0.5
    mesh = bpy.data.meshes.new(name + "_mesh")
    verts = [(-x, -0.5, 0), (x, -0.5, 0), (x, 0.5, 1), (-x, 0.5, 1), (-x, 0.5, 0), (x, 0.5, 0)]
    faces = [(0, 1, 2, 3), (4, 5, 1, 0), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(M["dirt"])
    o.data.materials.append(M["rock"])
    for i, p in enumerate(o.data.polygons):
        p.material_index = 0 if i == 0 else 1


def finish(name, folder):
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            for p in o.data.polygons:
                p.use_smooth = False
    bpy.ops.object.light_add(type="AREA", location=(-3, -4, 6))
    bpy.context.object.data.energy = 300
    bpy.context.object.data.size = 4
    bpy.ops.object.camera_add(location=(3, -4, 3), rotation=(math.radians(60), 0, math.radians(38)))
    bpy.context.scene.camera = bpy.context.object
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(folder / f"{name}.glb"), export_format="GLB", export_apply=True, export_yup=True)
    print("[dark_forest_replacement] wrote", folder / f"{name}.glb")


def make_cliff(name, corner=False):
    clear(); mats()
    cube("mass", (0, 0, .5), (1, 1, 1), M["rock"])
    cube("mud_cap", (0, 0, 1.04), (.96, .96, .08), M["dirt"])
    cube("moss", (-.2, .2, 1.1), (.42, .3, .04), M["moss"], .2)
    cube("front_break", (0, -.48, .35), (.52, .12, .56), M["rock"], .08)
    if corner:
        cube("side_break", (-.48, 0, .45), (.12, .52, .68), M["rock"], -.1)
    finish(name, DIRS["cliffs"])


def make_ramp(name, wide=False):
    clear(); mats()
    ramp_mesh("slope", wide)
    lip_x = .92 if wide else .56
    cube("left_lip", (-lip_x, .05, .45), (.12, .88, .2), M["rock"])
    cube("right_lip", (lip_x, .05, .45), (.12, .88, .2), M["rock"])
    cube("root", (0, -.18, .26), (.72, .08, .08), M["wood"], .22)
    finish(name, DIRS["ramps"])


def make_tree(name):
    clear(); mats()
    cone("trunk", (0, 0, .95), .18, .09, 1.9, M["wood"], 6, .15)
    for i in range(4): cube("branch_%d" % i, (0,0,.9+i*.28), (.1,.55-i*.08,.1), M["wood"], i*.7)
    cone("needles_low", (0,0,1.4), .55, .08, .58, M["moss"], 6)
    cone("needles_top", (0,0,1.85), .36, .04, .52, M["moss"], 6, .2)
    finish(name, DIRS["trees"])


def make_root(name):
    clear(); mats()
    cube("root_main", (0,0,.12), (.95,.16,.16), M["wood"], .2)
    cube("root_a", (-.22,.24,.12), (.6,.12,.12), M["wood"], -.55)
    cube("root_b", (.26,-.22,.12), (.55,.12,.12), M["wood"], .75)
    finish(name, DIRS["roots"])


def make_mushroom(name):
    clear(); mats()
    cone("stalk", (0,0,.45), .17, .11, .9, M["wood"], 7)
    ico("cap", (0,0,1.02), .48, (1.25,1,.45), M["fungus"])
    finish(name, DIRS["mushrooms"])


def make_rock(name):
    clear(); mats()
    for i in range(5): ico("rock_%d" % i, (-.32+i*.16, -.12 if i%2 else .16, .22+i*.05), .25, (1,.85,1+i*.08), M["rock"])
    cube("moss_patch", (.08,0,.52), (.38,.22,.08), M["moss"], .3)
    finish(name, DIRS["rocks"])


def make_shrine(name):
    clear(); mats()
    cube("base", (0,0,.14), (1.55,1.05,.28), M["rock"])
    cube("plinth", (0,0,.55), (.8,.58,.72), M["rock"], .08)
    cube("fallen", (-.58,.14,.3), (.24,.68,.28), M["rock"], -.32)
    cube("moss", (.06,0,.94), (.58,.4,.08), M["moss"])
    finish(name, DIRS["ruins"])


def make_torch(name):
    clear(); mats()
    cone("post", (0,0,.58), .07, .05, 1.1, M["wood"], 5)
    cube("crossbar", (0,0,1.02), (.36,.07,.07), M["wood"], .15)
    ico("flame", (0,0,1.28), .16, (.72,.72,1.25), M["glow"])
    finish(name, DIRS["decor"])


def main():
    make_cliff("df_cliff_side_a", False)
    make_cliff("df_cliff_corner_a", True)
    make_ramp("df_ramp_narrow_a", False)
    make_ramp("df_ramp_wide_a", True)
    make_tree("df_dead_tree_blocker_a")
    make_tree("df_dead_tree_blocker_b")
    make_root("df_twisted_root_blocker_a")
    make_mushroom("df_mushroom_blocker_a")
    make_mushroom("df_mushroom_blocker_b")
    make_rock("df_rock_blocker_a")
    make_rock("df_rock_blocker_b")
    make_shrine("df_ruined_shrine_a")
    make_torch("df_torch_prop_a")


if __name__ == "__main__":
    main()
