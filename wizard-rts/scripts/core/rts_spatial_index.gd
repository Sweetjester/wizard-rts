class_name RTSSpatialIndex
extends RefCounted

var bucket_size: float = 256.0
var buckets: Dictionary = {}

func rebuild(nodes: Array) -> void:
	buckets.clear()
	for node in nodes:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var key := bucket_for_position(node.global_position)
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(node)

func query_radius(position: Vector2, radius: float) -> Array[Node2D]:
	var results: Array[Node2D] = []
	var min_bucket := bucket_for_position(position - Vector2(radius, radius))
	var max_bucket := bucket_for_position(position + Vector2(radius, radius))
	var radius_sq := radius * radius
	for x in range(min_bucket.x, max_bucket.x + 1):
		for y in range(min_bucket.y, max_bucket.y + 1):
			var key := Vector2i(x, y)
			if not buckets.has(key):
				continue
			for node in buckets[key]:
				if is_instance_valid(node) and position.distance_squared_to(node.global_position) <= radius_sq:
					results.append(node)
	return results

func bucket_for_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / bucket_size), floori(position.y / bucket_size))
