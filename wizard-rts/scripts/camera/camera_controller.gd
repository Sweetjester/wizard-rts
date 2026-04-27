class_name CameraController
extends Camera2D

@export var pan_speed: float = 600.0
@export var zoom_speed: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.5
@export var edge_pan_margin: int = 20
@export var edge_pan_enabled: bool = true
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var bounds_padding: float = 96.0

var _drag_active: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _map_generator: Node
var _camera_bounds := Rect2()
var _has_camera_bounds := false

func _ready() -> void:
	zoom = Vector2(0.2, 0.2)
	position = Vector2(3800, 2000)
	_map_generator = get_node_or_null(map_generator_path)
	if _map_generator != null and _map_generator.has_signal("map_generated"):
		_map_generator.map_generated.connect(func(_summary: Dictionary) -> void:
			_refresh_camera_bounds()
		)
	call_deferred("_refresh_camera_bounds")

func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_edge_pan(delta)
	_clamp_to_map()

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
			_clamp_to_map()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = (zoom - Vector2(zoom_speed, zoom_speed)).clamp(
				Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
			_clamp_to_map()

func _handle_mouse_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_drag_active = event.pressed
		_drag_origin = get_viewport().get_mouse_position()
	if event is InputEventMouseMotion and _drag_active:
		position -= event.relative / zoom.x
		_clamp_to_map()

func _refresh_camera_bounds() -> void:
	if _map_generator == null:
		_map_generator = get_node_or_null(map_generator_path)
	if _map_generator == null or not _map_generator.has_method("get_world_bounds"):
		_has_camera_bounds = false
		return
	var bounds: Rect2 = _map_generator.call("get_world_bounds")
	_camera_bounds = bounds.grow(bounds_padding)
	_has_camera_bounds = _camera_bounds.size.x > 0.0 and _camera_bounds.size.y > 0.0
	_clamp_to_map()

func _clamp_to_map() -> void:
	if not _has_camera_bounds:
		return
	var viewport_size := get_viewport_rect().size / zoom
	var half := viewport_size * 0.5
	position = Vector2(
		_clamp_axis(position.x, _camera_bounds.position.x, _camera_bounds.end.x, half.x),
		_clamp_axis(position.y, _camera_bounds.position.y, _camera_bounds.end.y, half.y)
	)

func _clamp_axis(value: float, min_value: float, max_value: float, half_view: float) -> float:
	if max_value - min_value <= half_view * 2.0:
		return (min_value + max_value) * 0.5
	return clampf(value, min_value + half_view, max_value - half_view)
