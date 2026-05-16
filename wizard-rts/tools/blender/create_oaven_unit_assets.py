import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets_game" / "source" / "blender" / "kon" / "oaven"
EXPORT_DIR = ROOT / "assets_game" / "units" / "kon" / "oaven"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, emission=None, strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.82
        if emission:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = strength
    return material


def assign(obj, material):
    obj.data.materials.append(material)
    return obj


def shade_low_poly(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.shade_flat()
    finally:
        obj.select_set(False)
    return obj


def ico(name, loc, scale, material, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    assign(obj, material)
    return shade_low_poly(obj)


def cube(name, loc, scale, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, material)
    return shade_low_poly(obj)


def cylinder_between(name, a, b, radius, material, vertices=8):
    a = Vector(a)
    b = Vector(b)
    mid = (a + b) * 0.5
    direction = b - a
    length = direction.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    assign(obj, material)
    return shade_low_poly(obj)


def cone_between(name, a, b, radius1, radius2, material, vertices=8):
    a = Vector(a)
    b = Vector(b)
    mid = (a + b) * 0.5
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=direction.length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    assign(obj, material)
    return shade_low_poly(obj)


def wing(name, side, material):
    mesh = bpy.data.meshes.new(name + "Mesh")
    x = side
    verts = [
        (0.10 * x, 0.00, 1.15),
        (0.92 * x, -0.20, 2.05),
        (0.54 * x, 0.62, 1.30),
        (0.22 * x, 0.24, 1.08),
    ]
    faces = [(0, 1, 2), (0, 2, 3)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, material)
    return obj


def add_oaven_common(evolved=False):
    skin = mat("oaven_dark_teal_skin", (0.055, 0.22, 0.24, 1.0))
    skin_hi = mat("oaven_cold_teal_highlight", (0.11, 0.36, 0.40, 1.0))
    cloth = mat("oaven_ragged_red_wrap", (0.42, 0.12, 0.16, 1.0))
    dark = mat("oaven_charcoal_limb", (0.018, 0.035, 0.040, 1.0))
    wood = mat("oaven_dark_spear_wood", (0.11, 0.065, 0.035, 1.0))
    glow = mat("oaven_cyan_glow", (0.16, 0.92, 0.95, 1.0), (0.05, 1.0, 1.0, 1.0), 2.8)
    wing_mat = mat("oaven_glass_cyan_wings", (0.08, 0.74, 0.82, 0.45), (0.02, 0.9, 1.0, 1.0), 1.7)
    wing_mat.blend_method = "BLEND"
    wing_mat.use_screen_refraction = True

    body_scale = (0.40, 0.32, 0.62) if not evolved else (0.47, 0.38, 0.70)
    ico("body_hunched_thorax", (0, 0, 0.72), body_scale, skin_hi)
    ico("wide_oaven_head", (0, -0.10, 1.44), (0.56, 0.42, 0.34) if not evolved else (0.62, 0.45, 0.39), skin)
    ico("left_glowing_eye", (-0.24, -0.45, 1.52), (0.13, 0.065, 0.13), glow)
    ico("right_glowing_eye", (0.24, -0.45, 1.52), (0.13, 0.065, 0.13), glow)
    cone_between("left_antenna", (-0.15, -0.05, 1.73), (-0.62, -0.20, 2.18), 0.018, 0.004, dark, 6)
    cone_between("right_antenna", (0.15, -0.05, 1.73), (0.58, -0.14, 2.10), 0.018, 0.004, dark, 6)
    cube("ragged_scarf_front", (0, -0.40, 1.16), (0.86, 0.12, 0.24), cloth, (0.15, 0, 0))
    cube("shoulder_wrap", (0, -0.08, 1.05), (0.92, 0.18, 0.16), cloth, (0.0, 0.0, 0.12))

    for side in [-1, 1]:
        cylinder_between(f"upper_arm_{side}", (0.28 * side, -0.04, 1.03), (0.58 * side, -0.30, 0.72), 0.055, dark, 7)
        cylinder_between(f"forearm_wrap_{side}", (0.58 * side, -0.30, 0.72), (0.34 * side, -0.54, 0.50), 0.052, cloth if side > 0 else skin, 7)
        cylinder_between(f"thigh_{side}", (0.18 * side, 0.05, 0.42), (0.48 * side, 0.24, 0.16), 0.075, dark, 7)
        cylinder_between(f"shin_{side}", (0.48 * side, 0.24, 0.16), (0.72 * side, -0.02, 0.08), 0.05, skin, 7)
        ico(f"webbed_foot_{side}", (0.78 * side, -0.08, 0.045), (0.16, 0.075, 0.035), skin_hi, 1)

    cylinder_between("spear_shaft", (0.54, -0.58, 0.20), (0.70, -0.68, 2.32), 0.035, wood, 8)
    cone_between("cyan_spear_head", (0.70, -0.68, 2.32), (0.72, -0.70, 2.72), 0.105, 0.0, glow, 4)
    cube("red_wrist_binding", (0.50, -0.45, 0.62), (0.22, 0.08, 0.08), cloth, (0.1, 0.0, -0.2))

    if evolved:
        wing("left_gossamer_wing", -1, wing_mat)
        wing("right_gossamer_wing", 1, wing_mat)
        for side in [-1, 1]:
            cone_between(f"reinforced_back_spine_{side}", (0.16 * side, 0.20, 1.20), (0.28 * side, 0.50, 1.78), 0.04, 0.0, dark, 5)


def add_lights_and_camera():
    bpy.ops.object.light_add(type="AREA", location=(0, -4, 4))
    light = bpy.context.object
    light.name = "cool_rts_preview_area_light"
    light.data.energy = 420
    light.data.size = 4.0
    bpy.ops.object.camera_add(location=(2.8, -5.2, 3.0), rotation=(math.radians(60), 0, math.radians(28)))
    bpy.context.scene.camera = bpy.context.object


def export_asset(name, evolved=False):
    clear_scene()
    add_oaven_common(evolved)
    add_lights_and_camera()
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0, 0))
    bpy.context.object.name = name + "_origin"
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type == "MESH")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / f"{name}.blend"))
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT_DIR / f"{name}.glb"),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
    )
    print(f"[OavenAssets] exported {EXPORT_DIR / (name + '.glb')}")


def main():
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    export_asset("oaven_spear", evolved=False)
    export_asset("oaven_jumper", evolved=True)


if __name__ == "__main__":
    main()
