extends Sprite2D

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const ROOT := "res://assets_game/units/kon/hero/directional_v3/"
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const ACTIONS: Array[StringName] = [&"idle", &"move", &"attack", &"seal_away", &"observer_aura", &"biostorm", &"hit", &"death"]
static var _pages: Dictionary = {}
var facing_index := 2
var world_facing := Vector2.DOWN
var _page_key := ""
var current_action: StringName = &"idle"
var _clock := 0.0
var _shot_left := 0.0
var _hurt_left := 0.0
var _last_hp := -1

func _ready() -> void:
	set_process(true)
	hframes = 12
	vframes = 8
	position = Vector2.ZERO
	offset = Vector2(0,-138)
	scale = Vector2.ONE*0.43
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size",0.009)
	set_meta("foot_anchor_y",330.0)
	set_meta("death_row",7)
	set_meta("death_seconds",1.25)
	set_meta("corpse_hold_seconds",2.5)
	set_meta("preserve_painted_palette",true)
	_update_page()

func _update_page() -> void:
	var key: String = DIRECTIONS[facing_index]
	if key != _page_key:
		if not _pages.has(key): _pages[key] = load(ROOT+"kon_"+key+".png")
		texture = _pages[key]
		_page_key = key
	flip_h = false

func face_world_position(at: Vector2) -> void:
	var direction: Vector2 = at-get_parent().global_position
	if direction.length_squared()>.25: world_facing=direction.normalized()

func sync_view_facing() -> void:
	var unit := get_parent()
	var ability := StringName(unit.get("ability_animation_action"))
	# Stationary casts and observation keep world heading while the camera orbits.
	if ability not in [&"seal_away",&"biostorm",&"observer_aura"]:
		var direction: Vector2 = unit.get("velocity")
		# Keep the validity guard before accessing targets freed in the same frame.
		var target = unit.get("attack_target")
		if is_instance_valid(target) and (not target.has_method("is_alive") or target.is_alive()):
			direction = target.global_position-unit.global_position
		if direction.length_squared()>.25: world_facing=direction.normalized()
	var screen_heading := world_facing
	var view := unit.get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and is_instance_valid(view.get("camera")):
		screen_heading = Facing.camera_relative(world_facing,view.get("camera").global_basis)
	else:
		var camera := get_viewport().get_camera_2d()
		if camera!=null and not camera.ignore_rotation:
			screen_heading = world_facing.rotated(-camera.global_rotation)
	facing_index=Facing.sector(screen_heading,facing_index)
	_update_page()

func play_attack() -> void:
	_shot_left = 0.75

func _process(delta: float) -> void:
	var unit := get_parent()
	var hp := int(unit.get("health"))
	if _last_hp>=0 and hp<_last_hp: _hurt_left=0.30
	_last_hp=hp
	var next: StringName = &"move" if bool(unit.get("moving")) else &"idle"
	if _shot_left>0: next=&"attack"
	var ability := StringName(unit.get("ability_animation_action"))
	if ability in [&"seal_away", &"biostorm", &"observer_aura"]: next=ability
	if _hurt_left>0 and next!=&"observer_aura": next=&"hit"
	if next!=current_action:
		current_action=next
		_clock=0.0
	var index := int(_clock*10.0)%12
	if next==&"attack": index=clampi(int((0.75-_shot_left)*16),0,11)
	if next==&"hit": index=mini(11,int(_clock*40))
	if next in [&"seal_away",&"biostorm"]: index=mini(11,int(_clock*12))
	frame=ACTIONS.find(next)*12+index
	sync_view_facing()
	_clock+=delta
	_shot_left=maxf(0.0,_shot_left-delta)
	_hurt_left=maxf(0.0,_hurt_left-delta)
