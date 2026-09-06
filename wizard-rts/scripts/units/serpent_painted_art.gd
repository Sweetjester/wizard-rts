extends Sprite2D

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const ROOT := "res://assets_game/units/kon/serpent/directional_v3/"
static var _pages: Dictionary = {}
var facing_index := 0
var world_facing := Vector2.RIGHT
var _page_key := ""
var current_action := &"idle"
var _level := 0
var _clock := 0.0
var _attack_left := 0.0
var _hurt_left := 0.0
var _last_hp := -1

func _ready() -> void:
	hframes = 8
	vframes = 9
	scale = Vector2.ONE*1.152
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size",0.018)
	set_meta("death_row",7)
	set_meta("death_seconds",1.25)
	set_meta("corpse_hold_seconds",2.0)
	_update_level(1)

func _update_level(level: int) -> void:
	_level = clampi(level,1,6)
	_update_page()

func _update_page() -> void:
	var key := "serpent_%d_%s" % [_level,DIRECTIONS[facing_index]]
	if key==_page_key: return
	# Shared lazy cache avoids disk reads on repeated turns; BC7 pages are 4.5 MiB each.
	if not _pages.has(key): _pages[key]=load(ROOT+key+".png")
	texture = _pages[key]
	_page_key = key
	flip_h = false
	var heading := Vector2.from_angle(facing_index*PI/4)
	heading.y *= .6
	var anchor := Vector2(128,128)+heading*(3+2*(_level-1))*5.25
	offset = Vector2(128,128)-anchor
	set_meta("foot_anchor_y",anchor.y)

func sync_view_facing() -> void:
	var unit := get_parent()
	var heading: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target): heading=unit.attack_target.global_position-unit.global_position
	if heading.length_squared()>.25: world_facing=heading.normalized()
	var screen_heading := world_facing
	var view := unit.get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and is_instance_valid(view.get("camera")):
		screen_heading=Facing.camera_relative(world_facing,view.get("camera").global_basis)
	else:
		var camera := get_viewport().get_camera_2d()
		if camera!=null and not camera.ignore_rotation: screen_heading=world_facing.rotated(-camera.global_rotation)
	facing_index=Facing.sector(screen_heading,facing_index)
	_update_page()

func play_attack() -> void: _attack_left = 0.65

func _process(delta: float) -> void:
	var unit := get_parent()
	if not is_instance_valid(unit): return
	_update_level(int(unit.evolution_level))
	if _last_hp>unit.health and unit.health>0: _hurt_left = 0.3
	_last_hp = unit.health
	visible = not unit._stone_form_active
	var row := 1 if unit.moving else 0
	var index := int(_clock*8)%8
	if _attack_left>0:
		row = 2
		index = mini(7,int((0.65-_attack_left)/0.65*8))
	if _hurt_left>0:
		row = 8
		index = mini(7,int((0.3-_hurt_left)/0.3*8))
	if unit._stone_cast_remaining>0:
		row = 3
		index = clampi(int((1-unit._stone_cast_remaining/2.0)*7),0,7)
	elif unit.ability_animation_action == &"revert_stone": row = 5
	elif unit.ability_animation_action == &"evolve_growth": row = 6
	if row in [5,6]:
		var duration := 0.45 if row==5 else 1.0
		var remaining := maxf(0,float(unit._ability_animation_until_msec-Time.get_ticks_msec())/1000.0)
		index = clampi(int((1-remaining/duration)*7),0,7)
	if unit._stone_form_active: row = 4
	current_action = [&"idle",&"move",&"attack",&"harden",&"wall",&"revert",&"evolve",&"death",&"hit"][row]
	frame = row*8+index
	sync_view_facing()
	_clock += delta
	_attack_left = maxf(0,_attack_left-delta)
	_hurt_left = maxf(0,_hurt_left-delta)
