class_name DeterministicRng
extends RefCounted

const _A := 1664525
const _C := 1013904223
const _MASK := 0xffffffff

var _state: int

func _init(seed: int = 1) -> void:
	_state = seed & _MASK
	if _state == 0:
		_state = 1

func get_state() -> int:
	return _state

func set_state(value: int) -> void:
	_state = value & _MASK
	if _state == 0:
		_state = 1

func next_u32() -> int:
	_state = int((_A * _state + _C) & _MASK)
	return _state

func range_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return min_value + int(next_u32() % (max_value - min_value + 1))

func chance_per_mille(threshold: int) -> bool:
	return int(next_u32() % 1000) < clampi(threshold, 0, 1000)

func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[range_int(0, items.size() - 1)]

func fork(salt: int) -> DeterministicRng:
	var forked := DeterministicRng.new(_state ^ salt)
	forked.next_u32()
	return forked
