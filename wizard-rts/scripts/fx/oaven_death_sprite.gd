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
	var first := int(art.get_meta("death_row",5))*hframes
	frame=first
	var tween:=create_tween()
	tween.tween_method(func(t: float) -> void: frame=first+mini(hframes-1,int(t*hframes)),0.0,1.0,1.0)
	tween.tween_interval(1.2)
	tween.tween_property(self,"modulate:a",0.0,0.7)
	tween.tween_callback(queue_free)
