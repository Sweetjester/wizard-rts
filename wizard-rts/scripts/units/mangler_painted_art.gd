extends Sprite2D

var _form := ""
var _clock := 0.0
var _hurt := 0.0
var _last_hp := -1
var _pips: Sprite3D
var _pip_canvas: Sprite2D
var _pip_count := -1

func _ready() -> void:
	hframes = 12
	vframes = 9
	scale = Vector2.ONE * 0.48
	offset = Vector2(0,-138)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size", 0.0075)
	set_meta("foot_anchor_y", 330.0)
	set_meta("death_row", 8)
	set_meta("death_seconds", 1.0)
	set_meta("corpse_hold_seconds", 2.0)
	_update_form()
	_pip_canvas = Sprite2D.new()
	_pip_canvas.position = Vector2(0,-310)
	add_child(_pip_canvas)
	var view := get_parent().get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view):
		_pips = Sprite3D.new()
		_pips.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_pips.pixel_size = 0.012
		view.add_child(_pips)

func _update_form() -> void:
	var form := "winged_mangler" if get_parent().unit_archetype == &"winged_mangler" else "mangler"
	if form == _form: return
	_form = form
	texture = load("res://assets_game/units/kon/mangler/painted_v1/"+form+".png")

func _process(delta: float) -> void:
	var unit := get_parent()
	_update_form()
	_clock += delta * (1.0 + unit.momentum_stacks*0.08)
	if _last_hp > unit.health: _hurt = 0.3
	_last_hp = unit.health
	_hurt = maxf(0.0,_hurt-delta)
	var row := 1 if unit.moving else 0
	var index := int(_clock*16.0)%12
	var since_attack := float(Time.get_ticks_msec()-unit._last_melee_attack_msec)/1000.0
	if since_attack < 0.65:
		row = 2
		index = clampi(int(since_attack/0.65*12),0,11)
	if _hurt > 0:
		row = 3
		index = clampi(int((0.3-_hurt)*40),0,11)
	if unit.ability_animation_action == &"evolve" and Time.get_ticks_msec() < unit._ability_animation_until_msec:
		row = 7
	if unit.leap_age >= 0:
		var age: float = unit.leap_age
		row = 4 if age < unit.LEAP_WINDUP else 5 if not unit.leap_landed else 6
		var start: float = 0.0 if row == 4 else unit.LEAP_WINDUP if row == 5 else unit.LEAP_WINDUP+unit.LEAP_FLIGHT
		var duration: float = unit.LEAP_FLIGHT if row == 5 else unit.LEAP_WINDUP
		index = clampi(int((age-start)/duration*12),0,11)
	frame = row*12+index
	var direction: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target): direction = unit.attack_target.global_position-unit.global_position
	if unit.leap_age >= 0: direction = unit.leap_target-unit.leap_start
	if absf(direction.x)>0.5: flip_h = direction.x < 0
	offset.y = -138.0-unit.leap_height/scale.y
	set_meta("foot_anchor_y", 330.0+unit.leap_height/scale.y)
	_update_pips(unit)

func _update_pips(unit: Node) -> void:
	if unit.momentum_stacks != _pip_count:
		_pip_count = unit.momentum_stacks
		var img := Image.create(64,10,false,Image.FORMAT_RGBA8)
		for i in 5:
			img.fill_rect(Rect2i(i*13,0,11,10), Color("101d22"))
			img.fill_rect(Rect2i(i*13+2,2,7,6), (Color("ed667a") if _pip_count==5 else Color("7ce8e3")) if i<_pip_count else Color("344751"))
		_pip_canvas.texture = ImageTexture.create_from_image(img)
		if is_instance_valid(_pips): _pips.texture = _pip_canvas.texture
	_pip_canvas.visible = unit.selected or _pip_count > 0
	if is_instance_valid(_pips):
		var view := _pips.get_parent()
		_pips.global_transform = view._unit_transform(unit, 2.4+unit.leap_height/64.0)
		var fog: Node = view.get("fog_of_war")
		_pips.visible = _pip_canvas.visible and not unit.is_banished() and (fog==null or fog.is_world_position_visible(unit.global_position))

func _exit_tree() -> void:
	if is_instance_valid(_pips): _pips.queue_free()
