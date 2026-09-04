extends SceneTree

# Runs the PASS/FAIL cases structures declare about THEMSELVES.
#
# Schema 1.1 lets a structure ship `validation_tests` alongside its geometry.
# That is a better arrangement than assertions written afterwards by whoever
# implemented the loader: the author states what the building is supposed to do,
# and the engine either agrees or does not. So these are executed verbatim
# rather than reinterpreted, and any structure that declares them is picked up
# automatically -- no test file needs editing when a new one is authored.
#
# Kon's Observation Wizard Tower is the first structure to use this. Its six
# cases cover the full 26-level ascent, a closed gate, heavy exclusion from
# stairs, and balcony access.

func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var ran := 0
	var structures_with_tests := 0
	for structure_id in library.structure_ids():
		var cases := library.validation_tests_for(structure_id)
		if cases.is_empty():
			continue
		structures_with_tests += 1
		for case in cases:
			if not _run_case(library, structure_id, case):
				return
			ran += 1
	if structures_with_tests <= 0:
		_fail("No structure declared validation_tests -- the runner is asserting nothing")
		return
	print("[StructureValidationSmokeTest] %d authored cases across %d structures hold" % [ran, structures_with_tests])
	quit(0)

func _run_case(library: BlockStructureLibrary, structure_id: StringName, case: Dictionary) -> bool:
	var nav := library.navigation_for(structure_id)
	if nav == null:
		_fail("%s: could not build navigation" % structure_id)
		return false
	# Gate state starts at the structure's own declared default, then the case
	# overrides what it cares about. A case that says nothing about a gate is
	# therefore evaluated against the gate's resting state, not an assumption.
	nav.gate_states = library.gate_defaults_for(structure_id).duplicate()
	for key in case.get("state", {}):
		nav.gate_states[key] = bool(case["state"][key])

	var start := _to_cell(case.get("start", []))
	var goal := _to_cell(case.get("destination", []))
	var unit_class := StringName(case.get("unit_class", &"infantry"))
	var expected := str(case.get("expected", "PASS")) == "PASS"
	var reached := nav.can_reach(start, goal, unit_class)
	if reached != expected:
		_fail("%s / %s: %s from %s to %s expected %s, got %s" % [
			structure_id, case.get("id", "?"), unit_class, start, goal,
			case.get("expected"), "PASS" if reached else "FAIL"])
		return false
	return true

func _to_cell(value: Array) -> Vector3i:
	if value.size() < 3:
		return Vector3i.ZERO
	return Vector3i(int(value[0]), int(value[1]), int(value[2]))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
