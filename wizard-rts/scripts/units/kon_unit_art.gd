extends Sprite2D

@export var sheet_columns: int = 3
@export var sheet_rows: int = 8
@export var frame_time_idle: float = 0.28
@export var frame_time_move: float = 0.12
@export var frame_time_attack: float = 0.09
@export var frame_offset: Vector2 = Vector2(0, -20)
@export var art_scale: Vector2 = Vector2.ONE
@export var move_bob_pixels: float = 3.0
@export var attack_lunge_pixels: float = 6.0
@export var attack_squash: float = 0.08

var _elapsed := 0.0
var _frame := 0
var _base_position := Vector2.ZERO

func _ready() -> void:
	centered = true
	offset = frame_offset
	_base_position = position
	scale = art_scale
	if texture != null:
		hframes = max(1, sheet_columns)
		vframes = max(1, sheet_rows)
		frame = 0

func _process(delta: float) -> void:
	var parent := get_parent()
	if parent == null or texture == null:
		return
	hframes = max(1, sheet_columns)
	vframes = max(1, sheet_rows)
	var is_moving := bool(parent.get("moving"))
	var state := StringName(parent.get("unit_state"))
	var frame_time := frame_time_idle
	if is_moving:
		frame_time = frame_time_move
	elif state == &"attacking":
		frame_time = frame_time_attack
	_elapsed += delta
	if _elapsed >= frame_time:
		_elapsed = 0.0
		_frame = (_frame + 1) % hframes
	if sheet_columns >= 8 and sheet_rows <= 2:
		var state_row := 1 if state == &"attacking" else 0
		frame = state_row * hframes + _direction_row(parent)
	else:
		frame = _direction_row(parent) * hframes + _frame
	_apply_motion(parent, is_moving, state)

func _apply_motion(parent: Node, is_moving: bool, state: StringName) -> void:
	var time := float(parent.get("_visual_elapsed"))
	var direction := _facing_sign(parent)
	var bob := 0.0
	var sway := 0.0
	var lunge := 0.0
	var squash := Vector2.ONE
	if is_moving:
		var stride := sin(time * 15.0)
		bob = -absf(stride) * move_bob_pixels
		sway = sin(time * 7.5) * 1.4
		squash = Vector2(1.0 + absf(stride) * 0.035, 1.0 - absf(stride) * 0.035)
	elif state == &"attacking":
		var punch := absf(sin(time * 18.0))
		lunge = punch * attack_lunge_pixels * direction
		bob = -punch * 2.0
		squash = Vector2(1.0 + punch * attack_squash, 1.0 - punch * attack_squash * 0.65)
	elif state == &"stunned":
		sway = sin(time * 24.0) * 2.0
	position = _base_position + Vector2(lunge + sway, bob)
	scale = Vector2(art_scale.x * squash.x, art_scale.y * squash.y)

func _direction_row(parent: Node) -> int:
	var velocity := Vector2.ZERO
	if parent is CharacterBody2D:
		velocity = parent.velocity
	var target := Vector2.ZERO
	var attack_target = parent.get("attack_target")
	if attack_target != null and is_instance_valid(attack_target) and attack_target is Node2D:
		target = attack_target.global_position - parent.global_position
	elif velocity.length_squared() > 4.0:
		target = velocity
	elif not bool(parent.get("path").is_empty()):
		var path: Array = parent.get("path")
		target = Vector2(path[0]) - parent.global_position
	else:
		target = Vector2(float(parent.get("_facing_sign")), 0.25)
	if target.length_squared() <= 0.01:
		return 0
	var angle := target.angle()
	var index := posmod(int(round((angle + PI * 0.5) / (TAU / 8.0))), 8)
	return [0, 1, 2, 3, 4, 5, 6, 7][index]

func _facing_sign(parent: Node) -> float:
	var facing := float(parent.get("_facing_sign"))
	if absf(facing) < 0.1:
		return 1.0
	return signf(facing)
