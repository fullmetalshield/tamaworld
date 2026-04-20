class_name Characters
extends RefCounted

const DATA_PATH := "res://data/characters.json"

static var _cache: Array = []

static func all() -> Array:
	if _cache.is_empty():
		var text := FileAccess.get_file_as_string(DATA_PATH)
		_cache = JSON.parse_string(text)
	return _cache

static func find(id: String) -> Dictionary:
	for c in all():
		if c.get("id", "") == id:
			return c
	return {}

static func by_field(field: String) -> Array:
	return all().filter(func(c): return c.get("field", "") == field)

static func eye_position(id: String) -> Vector2:
	var c := find(id)
	if c.is_empty():
		return Vector2.ZERO
	var p: Dictionary = c.get("eyePosition", {"x": 0, "y": 0})
	return Vector2(p.x, p.y)
