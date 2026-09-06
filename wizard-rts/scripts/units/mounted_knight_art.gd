extends Sprite2D

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const VISUAL_SCALE := 1.65
const ROOT := "res://assets_game/units/steel_force/mounted_knight/directional_v1/"
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const ACTIONS := [&"idle",&"move",&"charge",&"attack",&"ignite",&"ablaze_idle",&"ablaze_move",&"ablaze_attack",&"hit",&"death",&"ablaze_hit"]
static var _pages: Dictionary = {}
var facing_index := 2
var world_facing := Vector2.DOWN
var current_action := &"idle"
var _page_key := ""
var _clock := 0.0
var _hurt_left := 0.0
var _last_hp := -1
# The Knight runs the same momentum mechanic as the Mangler and, until now, had
# no way to show it. Five stacks kindle its axe for twelve seconds -- a bigger
# deal than the Mangler's charge, and completely invisible.
var _pips := MomentumPips.new()

func _ready() -> void:
	hframes=8
	vframes=11
	# The atlas fits bull and rider together; match the rider to the foot knight.
	scale=Vector2.ONE*.85*VISUAL_SCALE
	offset=Vector2(0,-90)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size",.014*VISUAL_SCALE)
	set_meta("preserve_painted_palette",true)
	set_meta("foot_anchor_y",218.0)
	set_meta("death_row",9)
	set_meta("death_seconds",.9)
	set_meta("corpse_hold_seconds",2.0)
	_update_page()
	# Above the rider rather than above the bull: the strip has to clear the
	# whole silhouette, and this one is mounted.
	_pips.attach(self, -250.0)

func _update_page() -> void:
	var key: String = DIRECTIONS[facing_index]
	if key==_page_key: return
	if not _pages.has(key): _pages[key]=load(ROOT+"mounted_knight_"+key+".png")
	texture=_pages[key]
	_page_key=key
	flip_h=false

func sync_view_facing() -> void:
	var unit := get_parent()
	var heading: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target) and (not unit.attack_target.has_method("is_alive") or unit.attack_target.is_alive()):
		heading=unit.attack_target.global_position-unit.global_position
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

func _process(delta: float) -> void:
	var unit := get_parent()
	if not is_instance_valid(unit): return
	_clock+=delta
	if _last_hp>unit.health and unit.health>0: _hurt_left=.3
	_last_hp=unit.health
	var burning: bool = unit.is_ablaze()
	var row := (6 if burning else (2 if unit.momentum_stacks>0 else 1)) if unit.moving else (5 if burning else 0)
	var index := int(_clock*(12 if unit.moving else 6))%8
	if burning and unit.ignition_age<.45:
		row=4
		index=clampi(int(unit.ignition_age/.45*8),0,7)
	if unit.attack_visual_age<.65:
		row=7 if burning else 3
		index=clampi(int(unit.attack_visual_age/.65*8),0,7)
	if _hurt_left>0:
		row=10 if burning else 8
		index=clampi(int((.3-_hurt_left)/.3*8),0,7)
	current_action=ACTIONS[row]
	frame=row*8+index
	_hurt_left=maxf(0,_hurt_left-delta)
	sync_view_facing()
	# Max read from the unit, not assumed: momentum_max_stacks is authored on the
	# archetype and a second unit could carry a different number.
	_pips.update(unit, unit.momentum_stacks, unit.max_momentum_stacks(), 4.4)

func _exit_tree() -> void:
	_pips.release()
