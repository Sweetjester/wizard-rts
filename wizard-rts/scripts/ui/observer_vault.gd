extends CanvasLayer

const Style := preload("res://scripts/ui/observer_theme.gd")
const Records := preload("res://scripts/ui/vault_records.gd")
const Card := preload("res://scripts/ui/vault_drawn_card.gd")
const BACKGROUND := preload("res://assets/ui/observer_vault/library_drawn_v2.png")
const RESEARCH := [
	[&"tier_two_hybrids", "Tier II Hybrids", "Break the second seal."],
	[&"tier_three_hybrids", "Tier III Hybrids", "Break the third seal."],
	[&"observer_sight", "Observer Sight", "Extend Kon's observation."],
	[&"observer_command", "Observer Command", "Deepen obedience."],
	[&"observer_oversight", "Oversight", "Strengthen the Observer."],
	[&"thorned_vines", "Thorned Vines", "The walls knit themselves shut."],
	[&"accelerated_evolution", "Accelerated Evolution", "New life arrives already changing."],
	[&"hardened_horrors", "Hardened Horrors", "Thicker hide. Heavier limbs."],
	[&"launcher_bile", "Launcher Bile", "A more caustic payload."]
]
var build_system: Node
var session: Node
var rts_world: Node
var vault: WeakRef
var overlay: Control
var content: VBoxContainer
var grid: Control
var hand: Control
var current_tier := 1
var _deal_hand := true
var _swipe_origin := Vector2.ZERO
var scroll: ScrollContainer
var search: LineEdit
var notice: Label
var balance: Label
var tabs: HBoxContainer
var section := "Creations"
var selected_id: StringName = &""
var specimen_index := -1
var _elapsed := 0.0
var _fingerprint := ""
var _seen: Dictionary = {}
var _previous_focus: WeakRef

func _ready() -> void:
	layer = 90
	session = get_node("/root/GameSession")
	_build_ui()
	overlay.hide()

func _build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.theme = Style.make()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var bg := TextureRect.new()
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.04, .075, .07, .80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	overlay.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	var head := HBoxContainer.new()
	page.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var title := Style.label("The Observer Vault", 34)
	title.add_theme_font_override("font", Style.display_font())
	titles.add_child(title)
	balance = Style.label("", 16, Style.CYAN)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(balance)
	_button(head, "Close", close_archive)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	page.add_child(tabs)
	for name in ["Creations", "Felled", "Research"]:
		var b := _button(tabs, name, func():
			section = name
			selected_id = &""
			search.clear()
			refresh()
		)
		b.toggle_mode = true
	search = LineEdit.new()
	search.placeholder_text = "Find in this tier"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 120
	tabs.add_child(search)
	search.text_changed.connect(func(_text): selected_id = &""; refresh())
	page.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)
	notice = Style.label("", 14, Style.BRASS)
	page.add_child(notice)
	overlay.resized.connect(_resize_grid)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open_archive(source: Node, build: Node, world: Node) -> bool:
	if not is_instance_valid(source) or source.get("owner_player_id") != 1 or source.get("complete") != true or int(source.get("health")) <= 0:
		return false
	vault = weakref(source)
	build_system = build
	rts_world = world
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	selected_id = &""
	specimen_index = -1
	section = "Creations"
	current_tier = 1
	_deal_hand = true
	search.clear()
	overlay.show()
	get_viewport().set_meta("observer_archive_open", get_instance_id())
	overlay.modulate.a = 0
	create_tween().tween_property(overlay, "modulate:a", 1.0, .28)
	refresh()
	search.grab_focus()
	return true

func close_archive() -> void:
	overlay.hide()
	_release_input()
	if _previous_focus != null and is_instance_valid(_previous_focus.get_ref()):
		_previous_focus.get_ref().grab_focus()
	else:
		get_viewport().gui_release_focus()

func _release_input() -> void:
	if get_viewport().get_meta("observer_archive_open", 0) == get_instance_id():
		get_viewport().remove_meta("observer_archive_open")

func _exit_tree() -> void:
	_release_input()

func _input(event: InputEvent) -> void:
	if overlay == null or not overlay.visible:
		return
	if section != "Research" and selected_id == &"":
		if event is InputEventScreenTouch:
			if event.pressed: _swipe_origin = event.position
			elif absf(event.position.x-_swipe_origin.x)>70:
				change_tier(-1 if event.position.x>_swipe_origin.x else 1)
				get_viewport().set_input_as_handled()
		if event is InputEventMouseButton and event.pressed and is_instance_valid(hand) and hand.get_global_rect().has_point(event.position):
			if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
				change_tier(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
				get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if selected_id != &"":
			selected_id = &""
			refresh()
		else:
			close_archive()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	# Keep army hotkeys out of the world while the archive owns the screen.
	if overlay.visible:
		if _event is InputEventKey and _event.pressed and section != "Research" and selected_id == &"" and _event.keycode in [KEY_LEFT, KEY_RIGHT]:
			change_tier(1 if _event.keycode == KEY_RIGHT else -1)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(overlay) or not overlay.visible:
		return
	if vault == null or not is_instance_valid(vault.get_ref()) or int(vault.get_ref().get("health")) <= 0 or vault.get_ref().get("complete") != true:
		close_archive()
		return
	_elapsed += delta
	if _elapsed < .5:
		return
	_elapsed = 0
	var state := str(build_system.researched_upgrade_ranks) + str(session.felled_specimens)
	if section == "Research" and is_instance_valid(build_system.economy_manager):
		balance.text = "%d Bio" % int(build_system.economy_manager.get_resources(1).get(&"bio", 0))
		for item in RESEARCH:
			var cost: int = build_system._upgrade_cost(item[0], build_system.upgrade_rank(item[0])+1)
			state += str(build_system.economy_manager.can_afford(1, {&"bio":cost}))
	var records: Array = Records.entries(section, build_system, rts_world, session) if section != "Research" else []
	for r in records:
		state += str(r.get("stats", {}))
		for ref in r.get("instances", []):
			state += str(Records.specimen_stats(ref))
	if state != _fingerprint:
		_fingerprint = state
		refresh()

func refresh() -> void:
	if not is_instance_valid(content):
		return
	var old_scroll := scroll.scroll_vertical
	var focus := get_viewport().gui_get_focus_owner()
	var focus_name := str(focus.name) if is_instance_valid(focus) and content.is_ancestor_of(focus) else ""
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	grid = null
	for tab in tabs.get_children():
		if tab is Button:
			tab.button_pressed = tab.text == section
	search.visible = section != "Research" and selected_id == &""
	balance.visible = section == "Research"
	if section == "Research":
		_research_page()
	elif selected_id != &"":
		_detail_page()
	else:
		_gallery()
	scroll.set_deferred("scroll_vertical", old_scroll)
	if not focus_name.is_empty():
		var replacement := content.find_child(focus_name, true, false) as Control
		if replacement != null:
			replacement.grab_focus.call_deferred()

func _gallery() -> void:
	var entries := Records.entries(section, build_system, rts_world, session)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	content.add_child(nav)
	var previous := _button(nav, "<", func(): change_tier(-1))
	previous.tooltip_text = "Previous tier"
	previous.disabled = current_tier == 0
	for tier in 5:
		var locked: bool = section == "Creations" and tier > build_system.unlocked_tier(1)
		var label: String = ["Observer", "I", "II", "III", "IV"][tier]
		var b := _button(nav, label, func(): choose_tier(tier))
		b.name = "Tier_" + str(tier)
		b.custom_minimum_size.x = 68
		b.toggle_mode = true
		b.button_pressed = tier == current_tier
		b.tooltip_text = "Tier %d / unresearched" % tier if locked else "Tier %d" % tier
		if locked: b.add_theme_color_override("font_color", Color("80928d"))
	var next := _button(nav, ">", func(): change_tier(1))
	next.tooltip_text = "Next tier"
	next.disabled = current_tier == 4
	hand = Control.new()
	hand.custom_minimum_size.y = 448
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(hand)
	grid = Control.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.add_child(grid)
	var shown := 0
	var locked_tier: bool = section == "Creations" and current_tier > int(build_system.unlocked_tier(1))
	if current_tier == 4:
		for record in entries:
			if int(record.tier) == 4 and not record.sealed: locked_tier = false
	for record in entries:
		if int(record.tier) != current_tier: continue
		if not search.text.is_empty() and not str(record.name).to_lower().contains(search.text.to_lower()): continue
		var card := Card.new()
		card.setup(record)
		card.size = Vector2(280,410)
		card.disabled = record.sealed
		grid.add_child(card)
		card.pressed.connect(func():
			selected_id = record.id
			specimen_index = -1
			scroll.scroll_vertical = 0
			refresh()
		)
		shown += 1
	hand.resized.connect(_resize_grid)
	_resize_grid.call_deferred()
	if locked_tier:
		var mist := ColorRect.new()
		mist.name = "TierFog"
		mist.set_anchors_preset(Control.PRESET_FULL_RECT)
		mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/ui/vault_fog.gdshader")
		mist.material = material
		hand.add_child(mist)
		var seal := VBoxContainer.new()
		seal.name = "TierSeal"
		seal.add_theme_constant_override("separation",12)
		hand.add_child(seal)
		seal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		seal.offset_left = -180
		seal.offset_right = 180
		seal.offset_top = -45
		seal.offset_bottom = 45
		var label := Style.label("Tier %s remains unobserved" % ["0","I","II","III","IV"][current_tier],24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seal.add_child(label)
		var requirement := "Research Tier %d Hybrids" % current_tier if current_tier <= 3 else "Unleash at the Observation Tower"
		var button := _button(seal,requirement,func(): section="Research"; selected_id=&""; refresh())
		button.disabled = current_tier > 3
	elif shown == 0:
		var empty := Style.label("No matching records in this tier." if not search.text.is_empty() else "Nothing observed at this tier.",23)
		empty.set_anchors_preset(Control.PRESET_CENTER)
		empty.position = Vector2(-190,-20)
		empty.size = Vector2(380,60)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hand.add_child(empty)
	notice.text = "TIER %s  /  %s" % [["0","I","II","III","IV"][current_tier], "Unresearched" if locked_tier else "%d specimens" % shown]

func choose_tier(tier: int) -> void:
	current_tier = clampi(tier,0,4)
	selected_id = &""
	search.clear()
	scroll.scroll_vertical = 0
	_deal_hand = true
	refresh()

func change_tier(direction: int) -> void:
	choose_tier(current_tier + direction)

func _resize_grid() -> void:
	if not is_instance_valid(grid): return
	var count := grid.get_child_count()
	var spacing := minf(252, (grid.size.x-330)/maxi(1,count-1))
	for i in count:
		var card = grid.get_child(i)
		var offset := float(i)-float(count-1)*.5
		var angle := deg_to_rad(offset*5.0)
		var at := Vector2(grid.size.x*.5-140+offset*spacing,16+absf(offset)*9)
		card.arrange(at,angle,_deal_hand)
	_deal_hand = false

func _detail_page() -> void:
	var r := Records.record_for(selected_id, section, build_system, rts_world, session)
	if r.is_empty():
		selected_id = &""
		_gallery()
		return
	_button(content, "Back to the shelves", func(): selected_id = &""; refresh())
	var row: BoxContainer = HBoxContainer.new() if overlay.size.x >= 800 else VBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	content.add_child(row)
	var card := Card.new()
	card.setup(r)
	row.add_child(card)
	var prose := VBoxContainer.new()
	prose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prose.add_theme_constant_override("separation", 14)
	row.add_child(prose)
	prose.add_child(Style.label(str(r.name), 30))
	if r.sealed:
		prose.add_child(Style.label(str(r.requirement), 23, Style.BRASS))
		_button(prose, "Visit Research", func(): section = "Research"; selected_id = &""; refresh())
		return
	prose.add_child(Style.label(str(r.blurb) if not str(r.blurb).is_empty() else str(r.role), 18, Style.BRASS))
	var stats: Dictionary = r.template_stats
	if not r.enemy:
		var picker := OptionButton.new()
		picker.add_item("Run template / newly created form", 0)
		for i in r.instances.size():
			picker.add_item("Living specimen %d" % (i+1), i+1)
		specimen_index = mini(specimen_index, r.instances.size()-1)
		picker.select(specimen_index+1)
		picker.item_selected.connect(func(index): specimen_index = index-1; refresh())
		prose.add_child(picker)
		if specimen_index >= 0:
			var live := Records.specimen_stats(r.instances[specimen_index])
			if not live.is_empty():
				stats = live
	prose.add_child(Style.label("FIELD MEASUREMENTS" if specimen_index >= 0 and not r.enemy else "RECORDED ATTRIBUTES", 13, Style.CYAN))
	for pair in [["max_health","Vitality"], ["attack_damage","Attack"], ["armor","Armour"], ["magic_armor","Magic armour"], ["attack_range_cells","Reach (cells)"], ["attack_speed_seconds","Attack interval (s)"], ["intelligence","Intelligence"]]:
		var value := float(stats.get(pair[0], 0))
		var baseline := float(r.base.get(pair[0], value))
		var delta := value-baseline
		var suffix := "   (%+.2f from base)" % delta if not is_zero_approx(delta) else ""
		prose.add_child(Style.label("%s   %s%s" % [pair[1], str(snappedf(value,.01)), suffix], 18, Style.CYAN if delta > 0 else (Style.RED if delta < 0 else Style.PAPER)))
	prose.add_child(HSeparator.new())
	prose.add_child(Style.label("THE RUN'S ALTERATIONS", 13, Style.BRASS))
	if r.changes.is_empty():
		prose.add_child(Style.label("No researched alterations.", 17))
	for change in r.changes:
		prose.add_child(Style.label("%s\n%s" % [change.label, change.effect], 17))
	if specimen_index >= 0:
		prose.add_child(Style.label("Individual measurements include evolution and active stat changes. Unattributed differences are shown against the catalog baseline.", 14, Style.BRASS))
	var d := UnitCatalog.get_definition(selected_id)
	for ability in d.get("passives", []) + d.get("actives", []):
		prose.add_child(Style.label(str(ability).replace("_", " ").capitalize(), 16))
	var next := StringName(d.get("evolves_to", &""))
	if next != &"" and not r.enemy:
		var next_record := Records.record_for(next, "Creations", build_system, rts_world, session)
		prose.add_child(Style.label("EVOLUTION", 13, Style.BRASS))
		prose.add_child(Style.label(str(next_record.requirement) if next_record.sealed else str(next_record.name), 17))
	notice.text = "Recorded from a defeated archetype" if r.enemy else "Live record / refreshed while the archive is open"

func _research_page() -> void:
	content.add_child(Style.label("Break the seals. Shape what follows.", 24, Style.BRASS))
	for item in RESEARCH:
		var id: StringName = item[0]
		var rank: int = build_system.upgrade_rank(id)
		var maximum: int = build_system.upgrade_max_rank(id)
		var cost: int = build_system._upgrade_cost(id, rank + 1)
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", 5)
		content.add_child(line)
		line.add_child(Style.label("%s  %d/%d" % [item[1], rank, maximum], 21))
		line.add_child(Style.label(str(item[2]), 15, Style.BRASS))
		var b := _button(line, "Complete" if rank >= maximum else "Research / %d Bio" % cost, func():
			var success: bool = build_system.research_upgrade(1, id)
			refresh()
			notice.text = "Research inscribed." if success else "Research unavailable. Check Bio, prior tier and the Vault."
		)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.name = "Research_" + str(id)
		var affordable: bool = is_instance_valid(build_system.economy_manager) and build_system.economy_manager.can_afford(1, {&"bio":cost})
		b.disabled = rank >= maximum or not affordable or (id == &"tier_three_hybrids" and build_system.upgrade_rank(&"tier_two_hybrids") == 0)
		if not affordable and rank < maximum:
			b.tooltip_text = "Requires %d Bio" % cost
		if id == &"tier_three_hybrids" and build_system.upgrade_rank(&"tier_two_hybrids") == 0:
			line.add_child(Style.label("Requires Tier II Hybrids", 14, Style.RED))
		content.add_child(HSeparator.new())
	notice.text = "Research affects this expedition."
