from __future__ import annotations

import argparse
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


def ensure_materials() -> None:
    for name in MATERIAL_NAMES:
        material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled:
            if name == "emissive":
                principled.inputs["Emission Color"].default_value = (0.55, 0.9, 1.0, 1.0)
                principled.inputs["Emission Strength"].default_value = 0.8
            elif name == "outline_proxy":
                principled.inputs["Base Color"].default_value = (0.02, 0.02, 0.025, 1.0)
            elif name == "cloth":
                principled.inputs["Base Color"].default_value = (0.45, 0.12, 0.08, 1.0)
            elif name == "weapon":
                principled.inputs["Base Color"].default_value = (0.32, 0.26, 0.2, 1.0)
            elif name == "wing":
                principled.inputs["Base Color"].default_value = (0.2, 0.58, 0.62, 0.65)
            else:
                principled.inputs["Base Color"].default_value = (0.35, 0.32, 0.25, 1.0)

    body = bpy.data.materials["body"]
    for obj in mesh_objects():
        existing_names = {slot.material.name for slot in obj.material_slots if slot.material}
        if not obj.material_slots:
            obj.data.materials.append(body)
        for name in MATERIAL_NAMES:
            if name not in existing_names:
                obj.data.materials.append(bpy.data.materials[name])


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
    import_model(input_model)
    normalize_orientation_for_godot()
    normalize_scale(args.scale_meters)
    clean_names(args.unit_id)
    ensure_materials()
    ensure_placeholder_animations()
    export_glb(output_glb)


if __name__ == "__main__":
    main()
