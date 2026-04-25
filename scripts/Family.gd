class_name Family
extends RefCounted

# Family-wide treasury. A single pot shared by every member of the lineage,
# persisted to user://family.json so it survives across sessions and
# protagonist deaths. Action rewards (Actions._complete) deposit here; the
# HUD reads `money()` to render the centred amount.

const SAVE_PATH := "user://family.json"

static var _money: int = 0
static var _loaded: bool = false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var data: Variant = JSON.parse_string(text)
		if data is Dictionary:
			_money = int(data.get("money", 0))

static func money() -> int:
	ensure_loaded()
	return _money

static func add_money(amount: int) -> void:
	if amount == 0:
		return
	ensure_loaded()
	_money += amount
	persist()

static func set_money(value: int) -> void:
	ensure_loaded()
	_money = value
	persist()

static func reset() -> void:
	_money = 0
	_loaded = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func persist() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"money": _money}))
