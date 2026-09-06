extends RefCounted

# Clockwise in screen coordinates: E SE S SW W NW N NE.
static func sector(heading: Vector2, previous: int = 2) -> int:
	if heading.length_squared() < .0001: return previous
	var angle := heading.angle()
	var center := float(previous)*PI/4
	# Four degrees of hysteresis prevents rapid flips while pathing near a boundary.
	if absf(wrapf(angle-center,-PI,PI)) < PI/8+deg_to_rad(4): return previous
	return posmod(roundi(angle/(PI/4)),8)

static func camera_relative(heading: Vector2, basis: Basis) -> Vector2:
	var right := Vector3(basis.x.x,0,basis.x.z).normalized()
	var toward := Vector3(basis.z.x,0,basis.z.z).normalized()
	var world := Vector3(heading.x,0,heading.y)
	return Vector2(world.dot(right),world.dot(toward))
