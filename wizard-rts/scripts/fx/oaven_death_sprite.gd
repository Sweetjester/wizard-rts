extends Sprite2D

func configure(unit: Node2D, art: Sprite2D) -> void:
	texture_filter=art.texture_filter
	texture=art.texture
	hframes=art.hframes
	vframes=art.vframes
	scale=art.scale
	offset=art.offset
	flip_h=art.flip_h
	modulate=art.modulate
	global_position=unit.global_position
	z_index=unit.z_index
	frame=5*12
	var tween:=create_tween()
	tween.tween_method(func(t: float) -> void: frame=60+mini(11,int(t*12.0)),0.0,1.0,1.0)
	tween.tween_interval(1.2)
	tween.tween_property(self,"modulate:a",0.0,0.7)
	tween.tween_callback(queue_free)
