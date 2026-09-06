extends SceneTree

func _initialize() -> void:
	for name in ["masonry", "slate", "timber", "details"]:
		var path: String = "res://assets/structures/steel_barracks_hd/"+name+".png.import"
		var config := ConfigFile.new()
		if config.load(path)!=OK:
			push_error("Import once in Godot before configuring: "+path)
			quit(1)
			return
		config.set_value("params","compress/mode",0)
		config.set_value("params","mipmaps/generate",true)
		config.set_value("params","process/size_limit",0)
		if config.save(path)!=OK:
			quit(1)
			return
	print("[BarracksImports] Lossless, native size, mipmaps. Reimport in Godot next.")
	quit()
