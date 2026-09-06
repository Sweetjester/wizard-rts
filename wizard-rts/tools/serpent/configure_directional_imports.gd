extends SceneTree

func _initialize() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://assets_game/units/kon/serpent/directional_v3/"):
		if not file.ends_with(".png.import"): continue
		var path := "res://assets_game/units/kon/serpent/directional_v3/"+file
		var config := ConfigFile.new()
		assert(config.load(path)==OK)
		config.set_value("params","compress/mode",2)
		config.set_value("params","compress/high_quality",true)
		config.set_value("params","mipmaps/generate",false)
		config.set_value("params","process/fix_alpha_border",true)
		assert(config.save(path)==OK)
		count += 1
	assert(count==48,"Import all 48 pages before configuring GPU compression")
	print("[Serpent8Import] PASS: configured 48 runtime pages; reimport in editor next")
	quit()
