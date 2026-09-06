extends Sprite2D

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const ROOT := "res://assets_game/units/kon/mangler/directional_v2/"
static var _pages: Dictionary = {}
var facing_index := 2
var world_facing := Vector2.DOWN
var current_action := 0
var _page_key := ""
var _form := ""
var _clock := 0.0
var _hurt := 0.0
var _last_hp := -1
# Shared with the Mounted Knight, which runs the same mechanic. It used to be
# implemented here and nowhere else, which is why the Knight had none.
var _pips := MomentumPips.new()

func _ready() -> void:
	hframes = 8
	vframes = 9
	scale = Vector2.ONE * 0.72
	offset = Vector2(0,-92)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size", 0.01125)
	set_meta("foot_anchor_y", 220.0)
	set_meta("death_row", 8)
	set_meta("death_seconds", 1.0)
	set_meta("corpse_hold_seconds", 2.0)
	_update_form()
	_pips.attach(self, -310.0 / 1.5)

func _update_form() -> void:
	var form := "winged_mangler" if get_parent().unit_archetype == &"winged_mangler" else "mangler"
	if form == _form: return
	_form = form
	_update_page()

func _update_page() -> void:
	var key: String = _form+"_"+DIRECTIONS[facing_index]
	if key == _page_key: return
	if not _pages.has(key): _pages[key] = load(ROOT+key+".png")
	texture = _pages[key]
	_page_key = key
	flip_h = false

func sync_view_facing() -> void:
	var unit := get_parent()
	var heading: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target): heading = unit.attack_target.global_position-unit.global_position
	if unit.leap_age >= 0: heading = unit.leap_target-unit.leap_start
	if heading.length_squared() > .25: world_facing = heading.normalized()
	var screen_heading := world_facing
	var view := unit.get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and is_instance_valid(view.get("camera")):
		screen_heading = Facing.camera_relative(world_facing,view.get("camera").global_basis)
	else:
		var camera := get_viewport().get_camera_2d()
		if camera != null and not camera.ignore_rotation:
			screen_heading = world_facing.rotated(-camera.global_rotation)
	facing_index = Facing.sector(screen_heading,facing_index)
	_update_page()

func _process(delta: float) -> void:
	var unit := get_parent()
	_update_form()
	_clock += delta * (1.0 + unit.momentum_stacks*0.08)
	if _last_hp > unit.health: _hurt = 0.3
	_last_hp = unit.health
	_hurt = maxf(0.0,_hurt-delta)
	var row := 1 if unit.moving else 0
	var index := int(_clock*10.6667)%8
	var since_attack := float(Time.get_ticks_msec()-unit._last_melee_attack_msec)/1000.0
	if since_attack < 0.65:
		row = 2
		index = clampi(int(since_attack/0.65*8),0,7)
	if _hurt > 0:
		row = 3
		index = clampi(int((0.3-_hurt)*26.6667),0,7)
	if unit.ability_animation_action == &"evolve" and Time.get_ticks_msec() < unit._ability_animation_until_msec:
		row = 7
		index = clampi(int((1.0-float(unit._ability_animation_until_msec-Time.get_ticks_msec())/1200.0)*8),0,7)
	if unit.leap_age >= 0:
		var age: float = unit.leap_age
		row = 4 if age < unit.LEAP_WINDUP else 5 if not unit.leap_landed else 6
		var start: float = 0.0 if row == 4 else unit.LEAP_WINDUP if row == 5 else unit.LEAP_WINDUP+unit.LEAP_FLIGHT
		var duration: float = unit.LEAP_FLIGHT if row == 5 else unit.LEAP_RECOVERY if row == 6 else unit.LEAP_WINDUP
		index = clampi(int((age-start)/duration*8),0,7)
	current_action = row
	frame = row*8+index
	sync_view_facing()
	offset.y = -92.0-unit.leap_height/scale.y
	set_meta("foot_anchor_y", 220.0+unit.leap_height/scale.y)
	_update_pips(unit)

func _update_pips(unit: Node) -> void:
	# leap_height lifts the strip with the unit while it is in the air, so the
	# pips stay over its head rather than hanging where it took off from.
	_pips.update(unit, unit.momentum_stacks, unit.MAX_MOMENTUM, 2.4 + unit.leap_height / 64.0)

func _exit_tree() -> void:
	_pips.release()
