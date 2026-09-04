class_name BlockStructureLibrary
extends RefCounted

# Loads the authored block-structure spec.
#
# The source of truth is data/block_structures/structures.yaml. Godot has no
# YAML parser and every other YAML in this project is Python-tooling-only, so
# tools/blocks/convert_structures.py builds the JSON this reads. Re-run it after
# editing the YAML -- the JSON is a build artefact, not something to hand-edit.

const DEFAULT_PATH := "res://resources/block_structures/structures.json"

var world: Dictionary = {}
var unit_classes: Dictionary = {}
var nav_types: Dictionary = {}
var materials: Dictionary = {}
# Problems the converter found in the authored data. Reported rather than
# repaired: the spec's instruction is to preserve the data and surface the
# ambiguity instead of inventing gameplay rules to paper over it.
var schema_problems: Array = []

var _raw_structures: Dictionary = {}
var _cache: Dictionary = {}

static func load_default() -> BlockStructureLibrary:
	return load_from(DEFAULT_PATH)

static func load_from(path: String) -> BlockStructureLibrary:
	var library := BlockStructureLibrary.new()
	if not FileAccess.file_exists(path):
		push_error("Block structure data missing at %s -- run tools/blocks/convert_structures.py" % path)
		return library
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Block structure data at %s is not a JSON object" % path)
		return library
	var data: Dictionary = parsed
	library.world = data.get("world", {})
	library.unit_classes = data.get("unit_classes", {})
	library.nav_types = data.get("nav_types", {})
	library.materials = data.get("materials", {})
	library.schema_problems = data.get("_schema_problems", [])
	library._raw_structures = data.get("structures", {})
	return library

func structure_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _raw_structures:
		ids.append(StringName(key))
	ids.sort()
	return ids

# Definitions are expanded lazily and cached: expanding every structure's cells
# up front would do a lot of work for structures a given map never places.
func get_definition(structure_id: StringName) -> BlockStructureDefinition:
	if _cache.has(structure_id):
		return _cache[structure_id]
	var data: Dictionary = _raw_structures.get(str(structure_id), {})
	if data.is_empty():
		return null
	var definition := BlockStructureDefinition.from_data(structure_id, data, materials)
	_cache[structure_id] = definition
	return definition

# The PASS/FAIL cases a structure ships with itself. Schema 1.1 authors these
# alongside the geometry, which makes them the structure's own acceptance
# criteria rather than assertions invented after the fact -- so they are run
# verbatim instead of being reinterpreted.
func validation_tests_for(structure_id: StringName) -> Array:
	return _raw_structures.get(str(structure_id), {}).get("validation_tests", [])

# Gate states a structure wants at rest. A gate with no declared default stays
# closed, which is the safe reading of an unconfigured gate.
func gate_defaults_for(structure_id: StringName) -> Dictionary:
	return _raw_structures.get(str(structure_id), {}).get("gate_defaults", {})

func navigation_for(structure_id: StringName) -> BlockStructureNavigation:
	var definition := get_definition(structure_id)
	if definition == null:
		return null
	return BlockStructureNavigation.new(definition, unit_classes, nav_types)
