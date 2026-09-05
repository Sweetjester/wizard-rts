extends Node3D

# Navigation commits immediately, so the heavy leaf moves to its matching
# pose immediately too. Both poses stay within the reserved door bay.
func set_open(open: bool) -> void:
	rotation.y = PI*0.5 if open else 0.0
	set_meta("open",open)
