class_name CombatFeedback
extends CanvasLayer

# Health bars over units, and a damage number every time something is hit.
#
# WHY SCREEN SPACE, AND WHY ONE NODE FOR BOTH:
#
# In 2D each unit drew its own bar in its own _draw(), which is the right answer
# there -- the bar is a few pixels above a sprite in the same space. The 3D view
# hides every CanvasItem in the map subtree (Map3DView._suppress_2d_presentation),
# so in 3D those bars exist, run, and are never on screen. That is the bug this
# fixes, and it is the same failure the drag rectangle had.
#
# A bar is a SCREEN thing anyway: it should be the same size whether the unit is
# near the camera or far from it, and it must never be occluded by the building
# the unit is standing behind. Both are free in screen space and awkward in any
# other. Damage numbers are the same shape of problem, so they live here too
# rather than in a second layer with a second copy of the projection.
#
# The projection is injected rather than assumed. Map3DView installs one that
# unprojects through its camera; with none installed this falls back to the 2D
# canvas transform, so the numbers work in both presentations. Bars are drawn
# only in 3D, because in 2D the units already draw their own and two sets of
# bars is worse than either.

# How long a number lives, and how far it climbs in that time.
const NUMBER_SECONDS := 1.05
const NUMBER_RISE_PIXELS := 58.0
# The pop: a number is born slightly small, overshoots, then settles. Nothing
# but taste -- it is what makes a hit feel like an event rather than a label.
const NUMBER_POP_SECONDS := 0.12
const NUMBER_POP_SCALE := 1.35
# Numbers past this are dropped rather than queued. A splash landing in a crowd
# can produce dozens in one frame, and the readable ones are the recent ones.
const MAX_NUMBERS := 96
# Hits worth less than this fraction of the target's max health are drawn small,
# hits worth more are drawn large. There is no critical-hit rule in this game;
# this is the honest equivalent -- size means "how much this mattered to THAT
# target", so a 40 into a Poorper reads bigger than a 40 into a Steel Knight.
const HEAVY_HIT_FRACTION := 0.18

const BAR_WIDTH := 42.0
const BAR_HEIGHT := 6.0
# Bars shrink with distance so a far-off skirmish does not carry the same visual
# weight as the fight in front of you, but never below this fraction.
const BAR_MIN_SCALE := 0.62
const BAR_FADE_DISTANCE := 90.0
# A crowd is where health bars stop helping.
#
# At five hundred units in a melee the bars merge into one red mass that hides
# the units underneath, and they are drawn every frame on the map built to
# MEASURE frame time -- so the readout would be partly measuring its own
# overlay. Past the threshold only damaged units get a bar, which is the
# information a player is actually looking for in a fight, and the total is
# capped at the nearest few. Below it, nothing changes.
const CROWD_THRESHOLD := 140
const MAX_BARS := 120

# The EMPTY half of the bar has to be as visible as the full half, or a bar at
# 90% and a bar at 20% look like the same short dash on a dark map -- which is
# how the first version of this read: floating red ticks with no track behind
# them. So the track is a lit slate rather than the near-black the 2D bars used,
# and it carries its own outline.
const COLOR_TRACK := Color("#22333A", 0.92)
const COLOR_OUTLINE := Color("#0A1612", 0.95)
const COLOR_PLAYER := Color("#7BC47F")
const COLOR_ENEMY := Color("#C13030")
const COLOR_NEUTRAL := Color("#D6C7AE")
const COLOR_LOW := Color("#E85A5A")
const COLOR_INCOMING := Color("#E85A5A")
const COLOR_OUTGOING := Color("#F2E4C4")
const COLOR_MAGIC := Color("#7DDDE8")
const COLOR_LETHAL := Color("#F0A24B")

@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var enabled: bool = true
@export var show_health_bars: bool = true
@export var show_damage_numbers: bool = true

var rts_world: Node

# Set by Map3DView: (point) -> Vector2, or Vector2.INF when the point is not on
# screen. Takes a Vector3 world point for bars and a Vector2 sim position for
# numbers. Null in the 2D presentation.
var project_3d: Callable = Callable()

# What to draw a bar over, refreshed by Map3DView at its own sync rate:
# [{ "unit": WeakRef, "head": Vector3, "distance": float }]. Empty in 2D.
var bar_entries: Array[Dictionary] = []

var _canvas: Control
var _numbers: Array[Dictionary] = []
var _font: Font

func _ready() -> void:
	layer = 30
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.name = "CombatFeedbackCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_feedback)
	add_child(_canvas)
	rts_world = get_node_or_null(rts_world_path)
	if rts_world != null and rts_world.has_signal("damage_applied"):
		rts_world.connect("damage_applied", _on_damage_applied)

func _process(delta: float) -> void:
	if not enabled:
		return
	var live := false
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i]["age"] = float(_numbers[i]["age"]) + delta
		if float(_numbers[i]["age"]) >= NUMBER_SECONDS:
			_numbers.remove_at(i)
		else:
			live = true
	# Redraw while anything is moving. Bars follow units, so they redraw as long
	# as there are any; numbers keep it alive for a second after the last hit.
	if live or not bar_entries.is_empty():
		_canvas.queue_redraw()

# --- damage numbers ---------------------------------------------------------

# The TARGET, not the attacker, decides where the number appears and what it
# says. That is the WoW convention and it is the right one: the question a
# player is asking is "how badly is that hurt", and a number floating off the
# shooter would answer a question nobody asked.
func _on_damage_applied(target: Node, amount: int, damage_type: StringName) -> void:
	if not enabled or not show_damage_numbers or amount <= 0:
		return
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.remove_at(0)
	var maximum_value: Variant = target.get("max_health")
	var maximum := maxf(1.0, float(maximum_value) if maximum_value != null else 1.0)
	var health_value: Variant = target.get("health")
	var lethal: bool = health_value != null and int(health_value) - amount <= 0
	var heavy: bool = float(amount) / maximum >= HEAVY_HIT_FRACTION
	var owner_value: Variant = target.get("owner_player_id")
	var mine: bool = owner_value != null and int(owner_value) == 1
	var color := COLOR_INCOMING if mine else COLOR_OUTGOING
	if damage_type == &"magic" and not mine:
		color = COLOR_MAGIC
	if lethal:
		color = COLOR_LETHAL
	_numbers.append({
		"target": weakref(target),
		# The position is captured now as well as tracked, so a number over a
		# unit that dies this instant still has somewhere to be.
		"anchor": (target as Node2D).global_position,
		"amount": amount,
		"color": color,
		"size": 26.0 if heavy or lethal else 18.0,
		# Scatter, so three hits in one second are three numbers rather than one
		# smeared column. Chosen once per number, not once per frame.
		"drift": randf_range(-26.0, 26.0),
		"age": 0.0,
	})
	_canvas.queue_redraw()

# --- drawing ----------------------------------------------------------------

func _draw_feedback() -> void:
	if not enabled:
		return
	if show_health_bars and _has_3d_projection():
		_draw_health_bars()
	if show_damage_numbers:
		_draw_numbers()

func _has_3d_projection() -> bool:
	return project_3d.is_valid()

func _draw_health_bars() -> void:
	var viewport_rect := _canvas.get_viewport_rect()
	var crowded := bar_entries.size() > CROWD_THRESHOLD
	var drawn := 0
	for entry in bar_entries:
		if drawn >= MAX_BARS:
			break
		var reference = entry.get("unit")
		var unit = reference.get_ref() if reference is WeakRef else reference
		if unit == null or not is_instance_valid(unit):
			continue
		var maximum_value: Variant = unit.get("max_health")
		var maximum := int(maximum_value) if maximum_value != null else 0
		if maximum <= 0:
			continue
		# Vector2.INF means "not on screen", and callers MUST check it:
		# unproject_position() of a point behind the camera returns a plausible
		# mirrored position, and drawing it puts health bars for units behind
		# you along the top of the frame.
		var at: Vector2 = project_3d.call(entry["head"])
		if at == Vector2.INF or not viewport_rect.has_point(at):
			continue
		var bar_scale: float = clampf(1.0 - float(entry.get("distance", 0.0)) / BAR_FADE_DISTANCE,
			BAR_MIN_SCALE, 1.0)
		var owner_value: Variant = unit.get("owner_player_id")
		var selected_value: Variant = unit.get("selected")
		var selected: bool = bool(selected_value) if selected_value != null else false
		var ratio := float(int(unit.get("health"))) / float(maximum)
		if crowded and ratio >= 1.0 and not selected:
			continue
		_draw_bar(at, ratio, int(owner_value) if owner_value != null else 0, bar_scale, selected)
		drawn += 1

func _draw_bar(at: Vector2, ratio: float, owner_id: int, bar_scale: float, selected: bool) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var width := BAR_WIDTH * bar_scale
	var height := maxf(3.0, BAR_HEIGHT * bar_scale)
	var fill := COLOR_NEUTRAL
	if owner_id == 1:
		fill = COLOR_PLAYER
	elif owner_id > 1:
		fill = COLOR_ENEMY
	if ratio < 0.35:
		fill = COLOR_LOW
	var origin := at - Vector2(width * 0.5, height * 0.5)
	var frame := Rect2(origin - Vector2(1.0, 1.0), Vector2(width + 2.0, height + 2.0))
	_canvas.draw_rect(frame, COLOR_OUTLINE, true)
	_canvas.draw_rect(Rect2(origin, Vector2(width, height)), COLOR_TRACK, true)
	if ratio > 0.0:
		_canvas.draw_rect(Rect2(origin, Vector2(width * ratio, height)), fill, true)
	_canvas.draw_rect(frame, COLOR_OUTLINE, false, 1.0)
	if selected:
		_canvas.draw_rect(frame.grow(1.0), Color("#7DDDE8", 0.9), false, 1.0)

func _draw_numbers() -> void:
	var viewport_rect := _canvas.get_viewport_rect()
	for number in _numbers:
		var age := float(number["age"])
		var t := age / NUMBER_SECONDS
		# Follows the target while it lives, then stays where it last was. A
		# number that snapped to the world origin when its unit died would be
		# the most visible thing on screen at exactly the wrong moment.
		var anchor: Vector2 = number["anchor"]
		var target = (number["target"] as WeakRef).get_ref()
		if target != null and is_instance_valid(target):
			anchor = (target as Node2D).global_position
			number["anchor"] = anchor
		var at := _sim_to_screen(anchor)
		if at == Vector2.INF:
			continue
		# Ease-out rise: quick off the target, slowing as it fades.
		at.y -= NUMBER_RISE_PIXELS * (1.0 - pow(1.0 - t, 2.0))
		at.x += float(number["drift"]) * t
		if not viewport_rect.grow(64.0).has_point(at):
			continue
		var pop := 1.0
		if age < NUMBER_POP_SECONDS:
			pop = lerpf(0.7, NUMBER_POP_SCALE, age / NUMBER_POP_SECONDS)
		elif age < NUMBER_POP_SECONDS * 2.0:
			pop = lerpf(NUMBER_POP_SCALE, 1.0, (age - NUMBER_POP_SECONDS) / NUMBER_POP_SECONDS)
		var font_size := int(round(float(number["size"]) * pop))
		var alpha: float = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		var text := str(int(number["amount"]))
		var half := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
		var draw_at := at - Vector2(half, 0.0)
		var color: Color = number["color"]
		# Outlined rather than shadowed: these are read against grass, stone and
		# a black night sky within the same frame, and a drop shadow vanishes on
		# the dark half.
		_canvas.draw_string_outline(_font, draw_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5,
			Color(0.02, 0.06, 0.05, alpha * 0.9))
		_canvas.draw_string(_font, draw_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(color, alpha))

# A number's anchor is a SIM position. In 3D the installed projection lifts it to
# head height and unprojects; in 2D it is the canvas transform and nothing else.
func _sim_to_screen(sim_position: Vector2) -> Vector2:
	if _has_3d_projection():
		return project_3d.call(sim_position)
	if _canvas == null or not _canvas.is_inside_tree():
		return Vector2.INF
	return _canvas.get_viewport().get_canvas_transform() * sim_position

# --- for tests --------------------------------------------------------------

func live_number_count() -> int:
	return _numbers.size()

func live_numbers() -> Array[Dictionary]:
	return _numbers
