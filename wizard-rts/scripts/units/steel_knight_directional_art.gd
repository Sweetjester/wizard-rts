extends Sprite2D

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const ROOT := "res://assets_game/units/steel_force/steel_knight/directional_v2/"
const DIRECTIONS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
static var _pages: Dictionary = {}
var facing_index := 2
var world_facing := Vector2.DOWN
var _page_key := ""
var clock := 0.0
var hurt := 0.0
var last_hp := -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hframes = 8
	vframes = 5
	scale = Vector2.ONE * .72
	offset = Vector2(0, -92)
	set_meta("foot_anchor_y", 220.0)
	set_meta("billboard_pixel_size", .012)
	set_meta("death_row", 4)
	set_meta("death_seconds", 1.25)
	set_meta("corpse_hold_seconds", 2.0)
	_update_page()

func _update_page() -> void:
	var key: String = DIRECTIONS[facing_index]
	if key == _page_key: return
	if not _pages.has(key): _pages[key] = load(ROOT + "steel_knight_" + key + ".png")
	texture = _pages[key]
	_page_key = key
	flip_h = false

func sync_view_facing() -> void:
	var unit := get_parent()
	var heading: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target) and unit.attack_target.is_alive():
		heading = unit.attack_target.global_position - unit.global_position
	if heading.length_squared() > .25: world_facing = heading.normalized()
	var screen_heading := world_facing
	var view := unit.get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and is_instance_valid(view.get("camera")):
		screen_heading = Facing.camera_relative(world_facing, view.get("camera").global_basis)
	else:
		var camera := get_viewport().get_camera_2d()
		if camera != null and not camera.ignore_rotation:
			screen_heading = world_facing.rotated(-camera.global_rotation)
	facing_index = Facing.sector(screen_heading, facing_index)
	_update_page()

func _process(delta: float) -> void:
	var unit := get_parent()
	clock += delta
	if last_hp > unit.health and unit.health > 0: hurt = .3
	last_hp = unit.health
	hurt = maxf(0, hurt - delta)
	var row := 1 if unit.moving else 0
	var index := int(clock * (6.0 if unit.moving else 4.0)) % 8
	if unit.attack_visual_age < .9:
		row = 2
		index = clampi(int(unit.attack_visual_age / .9 * 8), 0, 7)
	if hurt > 0 or unit.unit_state == &"stunned":
		row = 3
		index = clampi(int((.3 - hurt) / .3 * 8), 0, 7)
	frame = row * 8 + index
	sync_view_facing()
