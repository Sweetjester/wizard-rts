extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var lib = load("res://scripts/blocks/structure_library.gd").new()
	lib.call("load_library")
	var d = lib.call("get_definition", &"kons_arcane_citadel_01")
	print("solid cells: %d" % d.solid_cells.size())
	var t := Time.get_ticks_msec()
	var skin = BlockArchitecturalSkin.build(d)
	var t1 := Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	var frames = BlockArchitecturalSkin.build_window_frames(d)
	var t2 := Time.get_ticks_msec() - t
	print("skin: %d ms, %d pieces" % [t1, skin.multimesh.instance_count])
	print("frames: %d ms, %d pieces" % [t2, frames.multimesh.instance_count])
	quit(0)
