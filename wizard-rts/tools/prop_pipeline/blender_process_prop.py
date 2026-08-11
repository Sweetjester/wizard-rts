from __future__ import annotations

import argparse
import json
from pathlib import Path

import bpy
from mathutils import Vector


MATERIAL_NAMES = [
    "stone",
    "moss",
    "wood_bark",
    "bone",
    "iron",
    "accent_base",
    "accent_corrupted",
    "accent_hostile",
    "outline_proxy",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prop-id", required=True)
    parser.add_argument("--category", required=True)
    parser.add_argument("--input-model", required=True)
    parser.add_argument("--output-glb", required=True)
    parser.add_argument("--scale-meters", type=float, required=True)
    parser.add_argument("--target-polycount", type=int, default=0)
    parser.add_argument("--pivot", default="tile_center_at_ground")
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


def bounds() -> tuple[Vector, Vector]:
    meshes = mesh_objects()
    if not meshes:
        raise RuntimeError("Imported model did not contain any mesh objects.")
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
    return min_corner, max_corner


def normalize_scale_and_pivot(scale_meters: float, pivot: str) -> None:
    meshes = mesh_objects()
    if not meshes:
        raise RuntimeError("Imported model did not contain any mesh objects.")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    min_corner, max_corner = bounds()
    width = max_corner.x - min_corner.x
    depth = max_corner.y - min_corner.y
    largest_footprint_axis = max(width, depth)
    if largest_footprint_axis <= 0.001:
        raise RuntimeError("Imported model bounds are invalid; footprint is approximately zero.")
    factor = scale_meters / largest_footprint_axis
    for obj in meshes:
        obj.scale *= factor
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    min_corner, max_corner = bounds()
    center_x = (min_corner.x + max_corner.x) * 0.5
    center_y = (min_corner.y + max_corner.y) * 0.5
    if pivot == "tile_center_at_top_surface":
        z_offset = max_corner.z
    else:
        z_offset = min_corner.z
    for obj in meshes:
        obj.location.x -= center_x
        obj.location.y -= center_y
        obj.location.z -= z_offset


def normalize_orientation_for_godot() -> None:
    meshes = mesh_objects()
    if not meshes:
        raise RuntimeError("Imported model did not contain any mesh objects.")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


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


def mesh_triangle_count(obj: bpy.types.Object) -> int:
    return sum(1 for polygon in obj.data.polygons if len(polygon.vertices) == 3) + sum(
        max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons if len(polygon.vertices) != 3
    )


def cap_source_polycount(target_polycount: int, profile: dict) -> None:
    if target_polycount <= 0:
        return
    outline_multiplier = 2.0 if profile_bool(profile, "create_outline_proxy", False) else 1.0
    target_source_triangles = max(100, int(float(target_polycount) / outline_multiplier))
    current_triangles = sum(mesh_triangle_count(obj) for obj in mesh_objects())
    if current_triangles <= target_source_triangles:
        return
    ratio = max(0.05, min(0.98, float(target_source_triangles) / float(current_triangles)))
    for obj in mesh_objects():
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("RTS_target_polycount_cap", "DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)


def ensure_materials(profile: dict, prop_id: str, category: str) -> None:
    palette = profile.get("material_palette", {})
    for name in MATERIAL_NAMES:
        material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled:
            config = palette.get(name, {})
            fallback = {
                "stone": "#2E3A2F",
                "moss": "#3F5A3C",
                "wood_bark": "#161311",
                "bone": "#5C5648",
                "iron": "#2A2622",
                "accent_base": "#1A6D72",
                "accent_corrupted": "#6B1A55",
                "accent_hostile": "#3A1210",
                "outline_proxy": "#050604",
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
        if name == "outline_proxy":
            material.use_backface_culling = True

    discard_imported = profile_bool(profile, "discard_imported_materials", False)
    if discard_imported:
        for obj in mesh_objects():
            obj.data.materials.clear()
        rules = profile.get("assignment_rules", {})
        for obj in mesh_objects():
            chosen_name = material_name_for_object(obj.name, prop_id, category, rules)
            chosen = bpy.data.materials.get(chosen_name, bpy.data.materials["stone"])
            if not obj.material_slots:
                obj.data.materials.append(chosen)
            else:
                obj.material_slots[0].material = chosen
            existing_names = {slot.material.name for slot in obj.material_slots if slot.material}
            for name in MATERIAL_NAMES:
                if name not in existing_names:
                    obj.data.materials.append(bpy.data.materials[name])


def material_name_for_object(object_name: str, prop_id: str, category: str, rules: dict) -> str:
    lower = f"{object_name} {prop_id} {category}".lower().replace("_", " ")
    for material_name, rule_key in [
        ("accent_base", "accent_base_keywords"),
        ("accent_corrupted", "accent_corrupted_keywords"),
        ("accent_hostile", "accent_hostile_keywords"),
        ("bone", "bone_keywords"),
        ("iron", "iron_keywords"),
        ("wood_bark", "wood_bark_keywords"),
        ("moss", "moss_keywords"),
        ("stone", "stone_keywords"),
    ]:
        for keyword in rules.get(rule_key, []):
            if str(keyword).lower() in lower:
                return material_name
    return "stone"


def join_meshes_if_requested(profile: dict, prop_id: str) -> None:
    if not profile_bool(profile, "join_meshes", False):
        return
    meshes = mesh_objects()
    if len(meshes) <= 1:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    bpy.context.view_layer.objects.active.name = f"{prop_id}_mesh"
    bpy.context.view_layer.objects.active.data.name = f"{prop_id}_mesh_data"


def clean_names(prop_id: str) -> None:
    for index, obj in enumerate(mesh_objects(), start=1):
        obj.name = f"{prop_id}_mesh_{index:02d}"
        obj.data.name = f"{obj.name}_data"


def create_outline_proxies(profile: dict) -> None:
    if not profile_bool(profile, "create_outline_proxy", False):
        return
    outline_material = bpy.data.materials.get("outline_proxy")
    if outline_material is None:
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


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_animations=False,
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
    normalize_scale_and_pivot(args.scale_meters, args.pivot)
    process_geometry(profile)
    cap_source_polycount(args.target_polycount, profile)
    ensure_materials(profile, args.prop_id, args.category)
    join_meshes_if_requested(profile, args.prop_id)
    clean_names(args.prop_id)
    create_outline_proxies(profile)
    export_glb(output_glb)


if __name__ == "__main__":
    main()
