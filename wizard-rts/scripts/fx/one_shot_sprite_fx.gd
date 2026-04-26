class_name OneShotSpriteFx
extends Sprite2D

var frame_columns := 4
var frame_rows := 1
var frame_time := 0.075
var lifetime := 0.45
var drift := Vector2.ZERO
var _elapsed := 0.0
var _frame_elapsed := 0.0

func configure(new_texture: Texture2D, columns: int, rows: int, duration: float, visual_scale: Vector2, new_drift: Vector2 = Vector2.ZERO) -> void:
	texture = new_texture
	frame_columns = maxi(1, columns)
	frame_rows = maxi(1, rows)
	lifetime = maxf(0.05, duration)
	scale = visual_scale
	drift = new_drift
	centered = true
	hframes = frame_columns
	vframes = frame_rows
	frame = 0
	z_as_relative = false
	z_index = 5000

func _process(delta: float) -> void:
	_elapsed += delta
	_frame_elapsed += delta
	position += drift * delta
	var total_frames := maxi(1, frame_columns * frame_rows)
	if _frame_elapsed >= frame_time:
		_frame_elapsed = 0.0
		frame = mini(frame + 1, total_frames - 1)
	var ratio := clampf(_elapsed / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - smoothstep(0.72, 1.0, ratio)
	if ratio >= 1.0:
		queue_free()
