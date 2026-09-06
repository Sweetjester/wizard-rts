class_name RosterLedger
extends RefCounted

# What this run has done to your roster.
#
# The existing unit sheets read the catalog, which is the right answer to "what
# is a Horror" and the wrong answer to "what is MY Horror, twenty minutes into
# this run". In a roguelike the interesting number is never the base stat, it is
# the distance travelled from it -- and, more than that, WHERE that distance came
# from. A player who can see "156 HP" learns nothing they cannot get by squinting
# at a health bar. A player who can see "120 base, +40 from Hardened Horrors II,
# x1.3 from one evolution" knows what to buy next.
#
# So every figure here is derived live from the actual BuildSystem and the actual
# units on the field, and every change carries the name of the thing that caused
# it. Nothing is stored: a ledger written down would be a second copy of the
# game state, free to disagree with the first, and this is exactly the kind of
# screen nobody checks against reality.
#
# Deliberately NOT a balance readout. It reports what the game is doing, in the
# game's own terms; it does not editorialise about whether a unit is good.

# Upgrades that change a unit's numbers, and what they do per rank.
#
# This mirrors BuildSystem._apply_upgrades_to_unit() rather than calling it,
# because that function mutates a live node and the ledger describes a TYPE --
# there may be none of them on the field yet. The duplication is real and worth
# naming: if an upgrade's effect changes there, it must change here, and the
# smoke test asserts the two agree for the case that matters most.
const UNIT_UPGRADES := [
	{
		"id": &"hardened_horrors",
		"label": "Hardened Horrors",
		"family": &"horror",
		"max_health_per_rank": 20,
		"attack_damage_per_rank": 2,
		"note": "Thicker hide, heavier limbs.",
	},
	{
		"id": &"launcher_bile",
		"label": "Launcher Bile",
		"archetype": &"bio_launcher",
		"attack_damage_per_rank": 8,
		"note": "Caustic payload; wider splash.",
	},
	{
		"id": &"thorned_vines",
		"label": "Thorned Vines",
		"archetype": &"vinewall",
		"regeneration_per_rank": 3.0,
		"note": "The wall knits itself shut.",
	},
]

# Reads the run's state for one archetype. `build_system` and `rts_world` may be
# null -- outside a match this degrades to the plain catalog entry rather than
# refusing to render.
static func entry_for(archetype: StringName, build_system: Node, rts_world: Node) -> Dictionary:
	var definition := UnitCatalog.get_definition(archetype)
	if definition.is_empty():
		return {}
	var base := _base_stats(archetype, definition)
	var live := base.duplicate()
	var changes: Array[Dictionary] = []
	if UnitCatalog.is_evolved_form(archetype):
		live["max_health"] = UnitCatalog.fielded_max_hp(archetype)
		live["attack_damage"] = UnitCatalog.fielded_attack_damage(archetype)
		changes.append({"label": "First evolution", "effect": "%d HP, %d attack before research" % [live.max_health, live.attack_damage], "note": "Individual later evolutions are measured on living specimens."})

	if build_system != null and is_instance_valid(build_system):
		_apply_research(archetype, definition, build_system, live, changes)

	return {
		"archetype": archetype,
		"display_name": str(definition.get("display_name", str(archetype))),
		"tier": UnitCatalog.tier_of(archetype),
		"family": UnitCatalog.family_of(archetype),
		"blurb": str(definition.get("card_blurb", "")),
		"base": base,
		"live": live,
		"changes": changes,
		"lineage": _lineage(archetype),
		"availability": _availability(archetype, build_system),
		"field": _field_census(archetype, rts_world),
		"evolves_on_its_own": bool(definition.get("auto_evolves", false)),
		"evolution_seconds": float(definition.get("evolution_seconds", 0.0)),
	}

# Takes the archetype as well as the definition: a catalog entry does not carry
# its own key, so intelligence has to be looked up by name. Reading it from
# definition["id"] silently produced 0 for every unit, which hid every Observer
# Command line on every card -- a change the player paid for, invisible.
static func _base_stats(archetype: StringName, definition: Dictionary) -> Dictionary:
	return {
		"max_health": int(definition.get("max_hp", 0)),
		"armor": int(definition.get("armor", 0)),
		"magic_armor": int(definition.get("magic_armor", 0)),
		"attack_damage": int(definition.get("attack_damage", 0)),
		"attack_range_cells": float(definition.get("attack_range_cells", 0)),
		"attack_speed_seconds": float(definition.get("attack_speed_seconds", float(definition.get("attack_cooldown_ticks", 20)) / 20.0)),
		"move_speed": float(definition.get("move_speed", 0.0)),
		"regeneration_per_second": float(definition.get("regeneration_per_second", 0.0)),
		"intelligence": UnitCatalog.intelligence_of(archetype),
	}

# Every researched rank that touches this archetype, with what it did.
static func _apply_research(archetype: StringName, definition: Dictionary,
		build_system: Node, live: Dictionary, changes: Array[Dictionary]) -> void:
	for upgrade in UNIT_UPGRADES:
		if upgrade.has("family") and UnitCatalog.family_of(archetype) != upgrade["family"]:
			continue
		if upgrade.has("archetype") and archetype != upgrade["archetype"]:
			continue
		var rank: int = int(build_system.call("upgrade_rank", upgrade["id"]))
		if rank <= 0:
			continue
		var effects: Array[String] = []
		if upgrade.has("max_health_per_rank"):
			var hp: int = int(upgrade["max_health_per_rank"]) * rank
			live["max_health"] = int(live["max_health"]) + hp
			effects.append("+%d max HP" % hp)
		if upgrade.has("attack_damage_per_rank"):
			var dmg: int = int(upgrade["attack_damage_per_rank"]) * rank
			live["attack_damage"] = int(live["attack_damage"]) + dmg
			effects.append("+%d damage" % dmg)
		if upgrade.has("regeneration_per_rank"):
			var regen: float = float(upgrade["regeneration_per_rank"]) * rank
			live["regeneration_per_second"] = float(live["regeneration_per_second"]) + regen
			effects.append("+%.0f regen/s" % regen)
		changes.append({
			"label": "%s %s" % [upgrade["label"], _roman(rank)],
			"effect": ", ".join(effects),
			"note": str(upgrade.get("note", "")),
		})

	# Obedience is not a stat bonus, it is what lets you give orders at all --
	# so it is reported even though it moves no numbers on this card.
	var command_rank: int = int(build_system.call("upgrade_rank", &"observer_command"))
	if command_rank > 0 and int(live.get("intelligence", 0)) > 0:
		var before: int = int(live["intelligence"])
		var after: int = mini(UnitCatalog.INTELLIGENCE_BOUND, before + command_rank)
		if after != before:
			live["intelligence"] = after
			changes.append({
				"label": "Observer Command %s" % _roman(command_rank),
				"effect": "%s -> %s" % [UnitCatalog.intelligence_label(before),
					UnitCatalog.intelligence_label(after)],
				"note": "It listens more than it used to.",
			})

	if int(build_system.call("upgrade_rank", &"accelerated_evolution")) > 0:
		changes.append({
			"label": "Accelerated Evolution",
			"effect": "+28 evolution progress on spawn",
			"note": "They arrive already becoming something else.",
		})

# What this thing was, and what it is turning into. The chain is walked forward
# from the catalog and backward by search, so a card can show the whole arc from
# either end of it -- which is the shape of the run, not of the unit.
static func _lineage(archetype: StringName) -> Dictionary:
	var forward: Array[StringName] = []
	var cursor := archetype
	for _step in 4:
		var next := StringName(UnitCatalog.get_definition(cursor).get("evolves_to", &""))
		if next == &"" or forward.has(next):
			break
		forward.append(next)
		cursor = next
	var backward: StringName = &""
	for candidate in UnitCatalog.DEFINITIONS:
		if StringName(UnitCatalog.DEFINITIONS[candidate].get("evolves_to", &"")) == archetype:
			backward = StringName(candidate)
			break
	return {"from": backward, "to": forward}

# Why you can or cannot field this right now. A locked unit that simply does not
# appear teaches the player nothing; a locked unit that says what unlocks it is
# half a tutorial.
static func _availability(archetype: StringName, build_system: Node) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var session: Node = tree.root.get_node_or_null("GameSession") if tree != null else null
	var class_id: String = str(session.get("wizard_class_id")) if session != null else ""
	if class_id != "" and not UnitCatalog.is_unit_allowed_for_class(archetype, class_id):
		return {"available": false, "reason": "Not in this wizard's roster"}
	var tier := UnitCatalog.tier_of(archetype)
	if tier > UnitCatalog.MAX_TRAINABLE_TIER:
		return {"available": false, "reason": "Unleashed, never trained"}
	if build_system == null or not is_instance_valid(build_system):
		return {"available": true, "reason": ""}
	# Conscripted units are gated by Steel Conscription, not by Kon's hybrid
	# tiers -- reporting a Poorper as "available" because it is tier 1 would put
	# a card in the gallery saying you can build something you cannot.
	if UnitCatalog.is_foreign_recruit(archetype):
		if bool(build_system.call("can_recruit", archetype)):
			return {"available": true, "reason": ""}
		return {"available": false, "reason": str(build_system.call("recruitment_locked_reason", archetype))}
	if tier > int(build_system.call("unlocked_tier", 1)):
		return {"available": false, "reason": "Requires Tier %d Hybrids" % tier}
	return {"available": true, "reason": ""}

# How many are actually alive. The one number on the card that is about this
# minute rather than about the run.
static func _field_census(archetype: StringName, rts_world: Node) -> int:
	if rts_world == null or not is_instance_valid(rts_world) or not rts_world.has_method("all_units"):
		return 0
	var count := 0
	for unit in rts_world.call("all_units"):
		if not is_instance_valid(unit):
			continue
		if StringName(unit.get("unit_archetype")) != archetype:
			continue
		if int(unit.get("owner_player_id")) != 1:
			continue
		count += 1
	return count

static func _roman(rank: int) -> String:
	match rank:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(rank)
