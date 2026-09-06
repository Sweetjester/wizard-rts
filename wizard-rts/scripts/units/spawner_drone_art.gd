extends Sprite2D

const ACTIONS: Array[StringName] = [&"idle", &"move", &"attack", &"hit", &"death"]
var current_action: StringName = &"idle"
var _clock := 0.0
var _last_health := -1
var _hurt_left := 0.0

func _ready() -> void:
	texture = load("res://assets_game/units/kon/spawner_drone/painted_v1/drone.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hframes = 12
	vframes = 5
	scale = Vector2.ONE*.42
	offset = Vector2(0,-26)
	set_meta("billboard_pixel_size",.0066)
	set_meta("foot_anchor_y",154.0)
	set_meta("death_row",4)
	set_meta("death_seconds",.55)
	set_meta("corpse_hold_seconds",.3)

func _process(delta: float) -> void:
	var unit := get_parent()
	var hp := int(unit.get("health"))
	if _last_health >= 0 and hp < _last_health: _hurt_left = .25
	_last_health = hp
	_hurt_left = maxf(0,_hurt_left-delta)
	var next: StringName = &"move" if bool(unit.get("moving")) else &"idle"
	if unit.get("unit_state") == &"attacking": next = &"attack"
	if _hurt_left > 0 or unit.get("unit_state") == &"stunned": next = &"hit"
	if current_action != next:
		current_action = next
		_clock = 0
	_clock += delta
	var index := int(_clock*30)%12
	if next == &"hit": index = mini(11,int(_clock*44))
	frame = ACTIONS.find(next)*12+index
	var direction: Vector2 = unit.get("velocity")
	# NOT typed as Node2D. attack_target can hold a unit that was queue_free()d
	# earlier this same frame -- a killed unit is not actually gone until the end
	# of it -- and assigning a freed object to a TYPED local raises "Trying to
	# assign invalid previously freed instance" instead of giving null. The
	# is_instance_valid() below is the right check; it just never gets to run.
	#
	# The engine does not stop for it, so nothing looks broken from GDScript: it
	# raises once per frame, per unit, for as long as the stale reference is
	# there, each one with a stack capture written to the log and sent to the
	# attached debugger. That is what the freeze was.
	var target = unit.get("attack_target")
	if target != null and is_instance_valid(target): direction = target.global_position-unit.global_position
	if absf(direction.x) > .5: flip_h = direction.x < 0
