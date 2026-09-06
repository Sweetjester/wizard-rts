extends SceneTree

func _initialize() -> void:
	for label in ["masonry","surfaces","details"]:
		var path: String="res://assets/structures/observation_tower_hd/"+label+".png"
		var config := ConfigFile.new()
		assert(config.load(path+".import")==OK)
		config.set_value("params","compress/mode",0)
		config.set_value("params","mipmaps/generate",true)
		config.set_value("params","process/size_limit",0)
		assert(config.save(path+".import")==OK)
		var img := Image.load_from_file(path)
		print("[TowerHD] %s: %s; lossless, mipmaps, no size cap" % [label,img.get_size()])
	quit()
