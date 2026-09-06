extends Sprite2D

var clock := 0.0
var hurt := 0.0
var last_hp := -1

func _ready() -> void:
	hframes = 12
	vframes = 6
	var unit := get_parent()
	texture = load("res://assets_game/units/steel_force/painted_v1/"+str(unit.unit_archetype)+".png")
	scale = Vector2.ONE*(0.8 if unit.unit_archetype == &"proper_blimp" else 0.46 if unit.unit_archetype == &"steel_knight" else 0.36)
	offset = Vector2(0,-138)
	set_meta("foot_anchor_y",330.0)
	set_meta("billboard_pixel_size",0.014 if unit.unit_archetype == &"proper_blimp" else 0.008 if unit.unit_archetype == &"steel_knight" else 0.006)
	set_meta("death_row",4)
	set_meta("death_seconds",1.1)
	set_meta("corpse_hold_seconds",2.0)

func _process(delta: float) -> void:
	var unit := get_parent()
	clock += delta
	if last_hp > unit.health: hurt = 0.3
	last_hp = unit.health
	hurt = maxf(0,hurt-delta)
	var row := 1 if unit.moving else 0
	var index := int(clock*12)%12
	if unit.attack_visual_age < 0.7:
		row = 2
		index = clampi(int(unit.attack_visual_age/0.7*12),0,11)
	if hurt>0:
		row = 3
		index = clampi(int((0.3-hurt)*40),0,11)
	if unit.unit_archetype == &"proper_blimp":
		if unit.landed: row = 5
		var elevation: float = unit.visual_lift
		offset.y = -138-elevation/scale.y
		set_meta("foot_anchor_y",330.0+elevation/scale.y)
	frame = row*12+index
	if absf(unit.velocity.x)>0.5: flip_h = unit.velocity.x<0
