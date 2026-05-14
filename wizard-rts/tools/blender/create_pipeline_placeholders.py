"""
Create placeholder Blender/Godot pipeline assets for the wizard RTS.

Run from the repository root with Blender:

    blender --background --python tools/blender/create_pipeline_placeholders.py

Outputs:
    assets_game/source/blender/placeholders/cliff_chunk_a.blend
    assets_game/source/blender/placeholders/ramp_a.blend
    assets_game/source/blender/placeholders/tree_blocker_a.blend
    assets_game/terrain/cliffs/cliff_chunk_a.glb
    assets_game/terrain/ramps/ramp_a.glb
    assets_game/props/trees/tree_blocker_a.glb
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO_ROOT / "assets_game" / "source" / "blender" / "placeholders"
CLIFF_EXPORT_DIR = REPO_ROOT / "assets_game" / "terrain" / "cliffs"
RAMP_EXPORT_DIR = REPO_ROOT / "assets_game" / "terrain" / "ramps"
TREE_EXPORT_DIR = REPO_ROOT / "assets_game" / "props" / "trees"


def ensure_dirs() -> None:
    for folder in [SOURCE_DIR, CLIFF_EXPORT_DIR, RAMP_EXPORT_DIR, TREE_EXPORT_DIR]:
        folder.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.92
        bsdf.inputs["Metallic"].default_value = 0.0
    material.diffuse_color = color
    return material


def add_cube(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    rotation_z: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=(0.0, 0.0, rotation_z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def add_low_poly_ico(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def create_ramp_mesh(name: str, rock: bpy.types.Material, dirt: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "_mesh")
    verts = [
        (-0.5, -0.5, 0.0),
        (0.5, -0.5, 0.0),
        (0.5, 0.5, 1.0),
        (-0.5, 0.5, 1.0),
        (-0.5, 0.5, 0.0),
        (0.5, 0.5, 0.0),
    ]
    faces = [
        (0, 1, 2, 3),
        (4, 5, 1, 0),
        (3, 2, 5, 4),
        (0, 3, 4),
        (1, 5, 2),
    ]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(dirt)
    obj.data.materials.append(rock)
    for index, polygon in enumerate(obj.data.polygons):
        polygon.material_index = 0 if index == 0 else 1
    return obj


def set_flat_shading() -> None:
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            for polygon in obj.data.polygons:
                polygon.use_smooth = False


def add_camera_and_light() -> None:
    bpy.ops.object.light_add(type="AREA", location=(-3.0, -4.0, 6.0))
    light = bpy.context.object
    light.name = "preview_area_light"
    light.data.energy = 350.0
    light.data.size = 4.0

    bpy.ops.object.camera_add(location=(3.0, -4.0, 3.0), rotation=(math.radians(60.0), 0.0, math.radians(38.0)))
    camera = bpy.context.object
    camera.name = "preview_camera_rts_oblique"
    camera.data.lens = 45
    bpy.context.scene.camera = camera


def set_origin_marker(asset_name: str) -> None:
    empty = bpy.data.objects.new(asset_name + "_origin_center_ground", None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.3
    empty.location = (0.0, 0.0, 0.0)
    bpy.context.collection.objects.link(empty)


def save_and_export(asset_name: str, export_dir: Path) -> None:
    set_flat_shading()
    add_camera_and_light()
    set_origin_marker(asset_name)

    blend_path = SOURCE_DIR / f"{asset_name}.blend"
    glb_path = export_dir / f"{asset_name}.glb"

    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
    )
    print(f"[wizard-rts blender pipeline] wrote {blend_path}")
    print(f"[wizard-rts blender pipeline] wrote {glb_path}")


def create_cliff_chunk() -> None:
    clear_scene()
    dark_rock = make_material("mat_dark_rock", (0.12, 0.13, 0.12, 1.0))
    dirt = make_material("mat_dirt", (0.46, 0.28, 0.16, 1.0))

    add_cube("cliff_main_chunk_1x1", (0.0, 0.0, 0.5), (1.0, 1.0, 1.0), dark_rock)
    add_cube("cliff_dirt_cap", (0.0, 0.0, 1.04), (0.96, 0.96, 0.10), dirt)
    add_cube("cliff_left_chip", (-0.42, -0.12, 0.42), (0.16, 0.44, 0.72), dark_rock, 0.10)
    add_cube("cliff_front_chip", (0.18, -0.46, 0.32), (0.34, 0.12, 0.54), dark_rock, -0.08)
    add_cube("cliff_right_chip", (0.46, 0.22, 0.58), (0.10, 0.30, 0.78), dark_rock, 0.18)

    save_and_export("cliff_chunk_a", CLIFF_EXPORT_DIR)


def create_ramp() -> None:
    clear_scene()
    dark_rock = make_material("mat_dark_rock", (0.12, 0.13, 0.12, 1.0))
    dirt = make_material("mat_dirt", (0.54, 0.31, 0.16, 1.0))

    create_ramp_mesh("ramp_main_slope_low_to_high", dark_rock, dirt)
    add_cube("ramp_left_rock_lip", (-0.55, 0.08, 0.47), (0.12, 0.82, 0.20), dark_rock, 0.02)
    add_cube("ramp_right_rock_lip", (0.55, 0.08, 0.47), (0.12, 0.82, 0.20), dark_rock, -0.02)
    add_cube("ramp_top_landing_dirt", (0.0, 0.55, 1.02), (0.94, 0.18, 0.06), dirt)
    add_cube("ramp_bottom_landing_dirt", (0.0, -0.55, 0.03), (0.94, 0.18, 0.06), dirt)

    save_and_export("ramp_a", RAMP_EXPORT_DIR)


def create_tree_blocker() -> None:
    clear_scene()
    dead_wood = make_material("mat_dead_wood", (0.25, 0.14, 0.08, 1.0))
    dark_green = make_material("mat_dark_green_foliage", (0.06, 0.24, 0.11, 1.0))
    dirt = make_material("mat_dirt", (0.36, 0.22, 0.12, 1.0))

    add_cube("tree_footprint_base", (0.0, 0.0, 0.03), (0.82, 0.82, 0.06), dirt)
    add_cube("tree_dead_wood_trunk", (0.0, 0.0, 0.62), (0.24, 0.24, 1.18), dead_wood, 0.12)
    add_cube("tree_dead_wood_branch_a", (0.20, -0.08, 1.25), (0.16, 0.52, 0.16), dead_wood, -0.55)
    add_cube("tree_dead_wood_branch_b", (-0.18, 0.12, 1.10), (0.14, 0.44, 0.14), dead_wood, 0.76)
    add_low_poly_ico("tree_foliage_lump_main", (0.0, 0.0, 1.78), 0.50, (1.0, 0.92, 0.78), dark_green)
    add_low_poly_ico("tree_foliage_lump_left", (-0.32, 0.06, 1.48), 0.34, (1.0, 0.86, 0.78), dark_green)
    add_low_poly_ico("tree_foliage_lump_right", (0.28, -0.14, 1.52), 0.36, (0.92, 1.0, 0.76), dark_green)
    add_low_poly_ico("tree_foliage_lump_top", (0.06, 0.04, 2.12), 0.32, (0.90, 0.88, 0.82), dark_green)

    save_and_export("tree_blocker_a", TREE_EXPORT_DIR)


def main() -> None:
    ensure_dirs()
    create_cliff_chunk()
    create_ramp()
    create_tree_blocker()


if __name__ == "__main__":
    main()
