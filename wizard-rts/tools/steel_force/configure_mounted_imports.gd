extends SceneTree
const ROOT := "res://assets_game/units/steel_force/mounted_knight/directional_v1/"

func _initialize() -> void:
	var count := 0
	for file in DirAccess.get_files_at(ROOT):
		if not file.begins_with("mounted_knight_") or not file.ends_with(".png.import"): continue
		var config := ConfigFile.new()
		assert(config.load(ROOT+file)==OK)
		config.set_value("params","compress/mode",2)
		config.set_value("params","compress/high_quality",true)
		config.set_value("params","mipmaps/generate",false)
		config.set_value("params","process/fix_alpha_border",true)
		assert(config.save(ROOT+file)==OK)
		count+=1
	assert(count==8)
	print("[MountedImport] PASS: eight GPU-compressed pages configured; reimport next")
	quit()
