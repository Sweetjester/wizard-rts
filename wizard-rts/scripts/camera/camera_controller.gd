class_name CameraController
extends Camera2D

@export var pan_speed: float = 600.0
@export var zoom_speed: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.5
@export var edge_pan_margin: int = 20
@export var edge_pan_enabled: bool = true

var _drag_active: bool = false
var _drag_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	zoom = Vector2(1.0, 1.0)

func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_edge_pan(delta)

func _input(event: InputEvent) -> void:
	_handle_zoom(event)
	_handle_mouse_drag(event)

func _handle_keyboard_pan(delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):  dir.x -= 1
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_up"):    dir.y -= 1
	if Input.is_action_pressed("ui_down"):  dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta / zoom.x

func _handle_edge_pan(delta: float) -> void:
	if not edge_pan_enabled: return
	var mouse = get_viewport().get_mouse_position()
	var size  = get_viewport_rect().size
	var dir   = Vector2.ZERO
	if mouse.x < edge_pan_margin:  dir.x -= 1
	if mouse.x > size.x - edge_pan_margin: dir.x += 1
	if mouse.y < edge_pan_margin:  dir.y -= 1
	if mouse.y > size.y - edge_pan_margin: dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta / zoom.x

func _handle_zoom(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = (zoom + Vector2(zoom_speed, zoom_speed)).clamp(
				Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = (zoom - Vector2(zoom_speed, zoom_speed)).clamp(
				Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

func _handle_mouse_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_drag_active = event.pressed
		_drag_origin = get_viewport().get_mouse_position()
	if event is InputEventMouseMotion and _drag_active:
		position -= event.relative / zoom.x
