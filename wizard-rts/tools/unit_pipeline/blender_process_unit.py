from __future__ import annotations

import argparse
import json
from pathlib import Path

import bpy
from mathutils import Vector


MATERIAL_NAMES = ["body", "cloth", "weapon", "emissive", "wing", "outline_proxy"]
ANIMATION_NAMES = ["idle", "move", "attack", "death"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unit-id", required=True)
    parser.add_argument("--input-model", required=True)
    parser.add_argument("--output-glb", required=True)
    parser.add_argument("--scale-meters", type=float, required=True)
    parser.add_argument("--style-profile", default="")
    return parser.parse_args()


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_model(path: Path) -> None:
    suffix = path.suffix.lower()
    if suffix in [".glb", ".gltf"]:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    else:
        raise RuntimeError(f"Unsupported input model format: {path.suffix}")


def mesh_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def load_style_profile(path_text: str) -> dict:
    if not path_text:
        return {}
    path = Path(path_text)
    if not path.exists():
        raise RuntimeError(f"Style profile does not exist: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def profile_bool(profile: dict, key: str, fallback: bool) -> bool:
    return bool(profile.get("mesh_processing", {}).get(key, fallback))


def profile_float(profile: dict, key: str, fallback: float) -> float:
    return float(profile.get("mesh_processing", {}).get(key, fallback))


def color_tuple(hex_text: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    text = str(hex_text).strip().lstrip("#")
    if len(text) != 6:
        return (0.0, 0.0, 0.0, alpha)
    return (
        int(text[0:2], 16) / 255.0,
        int(text[2:4], 16) / 255.0,
        int(text[4:6], 16) / 255.0,
        alpha,
    )


def normalize_scale(scale_meters: float) -> None:
    meshes = mesh_objects()
    if not meshes:
        raise RuntimeError("Imported model did not contain any mesh objects.")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    min_corner = Vector((float("inf"), float("inf"), float("inf")))
    max_corner = Vector((float("-inf"), float("-inf"), float("-inf")))
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_corner.x = min(min_corner.x, world.x)
            min_corner.y = min(min_corner.y, world.y)
            min_corner.z = min(min_corner.z, world.z)
            max_corner.x = max(max_corner.x, world.x)
            max_corner.y = max(max_corner.y, world.y)
            max_corner.z = max(max_corner.z, world.z)
    height = max_corner.z - min_corner.z
    if height <= 0.001:
        raise RuntimeError("Imported model bounds are invalid; height is approximately zero.")
    factor = scale_meters / height
    for obj in meshes:
        obj.scale *= factor
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Put the origin/base on the ground plane for predictable Godot placement.
    min_z = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= min_z


def normalize_orientation_for_godot() -> None:
    meshes = mesh_objects()
    if not meshes:
        raise RuntimeError("Imported model did not contain any mesh objects.")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def clean_names(unit_id: str) -> None:
    for index, obj in enumerate(mesh_objects(), start=1):
        obj.name = f"{unit_id}_mesh_{index:02d}"
        obj.data.name = f"{obj.name}_data"


def process_geometry(profile: dict) -> None:
    merge_distance = profile_float(profile, "merge_by_distance", 0.0)
    decimate_ratio = profile_float(profile, "decimate_ratio", 1.0)
    use_flat_shading = profile_bool(profile, "flat_shading", False)
    use_weighted_normals = profile_bool(profile, "weighted_normals", False)
    remove_loose = profile_bool(profile, "remove_loose_geometry", True)
    for obj in mesh_objects():
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        if remove_loose or merge_distance > 0.0:
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            if remove_loose:
                bpy.ops.mesh.delete_loose()
            if merge_distance > 0.0:
                bpy.ops.mesh.remove_doubles(threshold=merge_distance)
            bpy.ops.object.mode_set(mode="OBJECT")
        if use_flat_shading:
            for polygon in obj.data.polygons:
                polygon.use_smooth = False
        if decimate_ratio > 0.0 and decimate_ratio < 0.999:
            modifier = obj.modifiers.new("RTS_silhouette_decimate", "DECIMATE")
            modifier.ratio = decimate_ratio
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        if use_weighted_normals:
            modifier = obj.modifiers.new("RTS_weighted_normals", "WEIGHTED_NORMAL")
            modifier.keep_sharp = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)


def ensure_materials(profile: dict) -> None:
    palette = profile.get("material_palette", {})
    for name in MATERIAL_NAMES:
        material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled:
            config = palette.get(name, {})
            fallback = {
                "body": "#162224",
                "cloth": "#4A1719",
                "weapon": "#302822",
                "emissive": "#24C8D7",
                "wing": "#1A6D72",
                "outline_proxy": "#020405",
            }.get(name, "#38332A")
            alpha = float(config.get("alpha", 1.0))
            principled.inputs["Base Color"].default_value = color_tuple(config.get("base_color", fallback), alpha)
            principled.inputs["Roughness"].default_value = float(config.get("roughness", 0.92))
            principled.inputs["Metallic"].default_value = float(config.get("metallic", 0.0))
            if "Alpha" in principled.inputs:
                principled.inputs["Alpha"].default_value = alpha
            if config.get("emission_color", ""):
                principled.inputs["Emission Color"].default_value = color_tuple(config.get("emission_color"), 1.0)
                principled.inputs["Emission Strength"].default_value = float(config.get("emission_strength", 0.0))
            elif name == "emissive":
                principled.inputs["Emission Color"].default_value = color_tuple("#35F1FF", 1.0)
                principled.inputs["Emission Strength"].default_value = 1.4
        if name == "wing" or float(palette.get(name, {}).get("alpha", 1.0)) < 1.0:
            material.blend_method = "BLEND"
            material.use_screen_refraction = True
        if name == "outline_proxy":
            material.use_backface_culling = True

    if profile_bool(profile, "discard_imported_materials", False):
        for obj in mesh_objects():
            obj.data.materials.clear()

    rules = profile.get("assignment_rules", {})
    body = bpy.data.materials["body"]
    for obj in mesh_objects():
        chosen_name = material_name_for_object(obj.name, rules)
        chosen = bpy.data.materials.get(chosen_name, body)
        if not obj.material_slots:
            obj.data.materials.append(chosen)
        else:
            obj.material_slots[0].material = chosen
        existing_names = {slot.material.name for slot in obj.material_slots if slot.material}
        for name in MATERIAL_NAMES:
            if name not in existing_names:
                obj.data.materials.append(bpy.data.materials[name])


def material_name_for_object(object_name: str, rules: dict) -> str:
    lower = object_name.lower()
    for material_name, rule_key in [
        ("emissive", "emissive_keywords"),
        ("wing", "wing_keywords"),
        ("cloth", "cloth_keywords"),
        ("weapon", "weapon_keywords"),
    ]:
        for keyword in rules.get(rule_key, []):
            if str(keyword).lower() in lower:
                return material_name
    return "body"


def create_outline_proxies(profile: dict) -> None:
    if not profile_bool(profile, "create_outline_proxy", False):
        return
    outline_material = bpy.data.materials.get("outline_proxy")
    if outline_material == None:
        return
    scale = profile_float(profile, "outline_scale", 1.025)
    source_meshes = list(mesh_objects())
    for obj in source_meshes:
        duplicate = obj.copy()
        duplicate.data = obj.data.copy()
        duplicate.name = f"{obj.name}_ink_outline"
        duplicate.data.name = f"{duplicate.name}_data"
        duplicate.scale = (obj.scale.x * scale, obj.scale.y * scale, obj.scale.z * scale)
        duplicate.data.materials.clear()
        duplicate.data.materials.append(outline_material)
        bpy.context.collection.objects.link(duplicate)
        duplicate.display_type = "TEXTURED"
        bpy.context.view_layer.objects.active = duplicate
        duplicate.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
        duplicate.select_set(False)


def ensure_placeholder_animations() -> None:
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 80
    root = bpy.data.objects.new("PlaceholderAnimationRoot", None)
    bpy.context.collection.objects.link(root)
    for obj in mesh_objects():
        obj.parent = root

    for action_name in ANIMATION_NAMES:
        action = bpy.data.actions.get(action_name) or bpy.data.actions.new(action_name)
        root.animation_data_create()
        root.animation_data.action = action
        root.location = (0.0, 0.0, 0.0)
        root.rotation_euler = (0.0, 0.0, 0.0)
        root.keyframe_insert(data_path="location", frame=1)
        root.keyframe_insert(data_path="rotation_euler", frame=1)
        if action_name == "move":
            root.location.z = 0.035
            root.keyframe_insert(data_path="location", frame=10)
        elif action_name == "attack":
            root.rotation_euler.z = -0.12
            root.keyframe_insert(data_path="rotation_euler", frame=8)
            root.rotation_euler.z = 0.16
            root.keyframe_insert(data_path="rotation_euler", frame=15)
        elif action_name == "death":
            root.rotation_euler.x = 1.35
            root.keyframe_insert(data_path="rotation_euler", frame=28)
        else:
            root.location.z = 0.02
            root.keyframe_insert(data_path="location", frame=20)
        root.location = (0.0, 0.0, 0.0)
        root.rotation_euler = (0.0, 0.0, 0.0)
        root.keyframe_insert(data_path="location", frame=40)
        root.keyframe_insert(data_path="rotation_euler", frame=40)
        root.animation_data.action = None


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_animations=True,
        export_yup=True,
    )


def main() -> None:
    args = parse_args()
    input_model = Path(args.input_model)
    output_glb = Path(args.output_glb)
    if not input_model.exists():
        raise RuntimeError(f"Input model does not exist: {input_model}")
    clear_scene()
    profile = load_style_profile(args.style_profile)
    import_model(input_model)
    normalize_orientation_for_godot()
    normalize_scale(args.scale_meters)
    clean_names(args.unit_id)
    process_geometry(profile)
    ensure_materials(profile)
    create_outline_proxies(profile)
    ensure_placeholder_animations()
    export_glb(output_glb)


if __name__ == "__main__":
    main()
