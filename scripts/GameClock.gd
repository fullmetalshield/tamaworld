extends Node

# Autoload. Tracks an in-game clock that advances slowly while the app is
# running. 1 real second = 1 game minute by default (60x scale).
# Persists across sessions via user://clock.json.

signal time_changed

const SAVE_PATH := "user://clock.json"
const GAME_MINUTES_PER_REAL_SECOND := 1.0
const DAY_START_MINUTES := 8 * 60  # Day 1 begins at 08:00

var _total_game_minutes: float = float(DAY_START_MINUTES)

func _ready() -> void:
	_load()
	time_changed.emit()

func _process(delta: float) -> void:
	var prev_min := int(_total_game_minutes)
	_total_game_minutes += delta * GAME_MINUTES_PER_REAL_SECOND
	var cur_min := int(_total_game_minutes)
	if cur_min != prev_min:
		time_changed.emit()
		if cur_min % 60 == 0:
			_save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save()

func get_day() -> int:
	return int(_total_game_minutes) / (24 * 60) + 1

func get_hour() -> int:
	return int(_total_game_minutes) / 60 % 24

func get_minute() -> int:
	return int(_total_game_minutes) % 60

func format_day() -> String:
	return "%d일차" % get_day()

func format_time() -> String:
	var h := get_hour()
	var m := get_minute()
	var period := "오전" if h < 12 else "오후"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%s %d:%02d" % [period, h12, m]

func advance_minutes(minutes: int) -> void:
	if minutes <= 0:
		return
	_total_game_minutes += float(minutes)
	time_changed.emit()
	_save()

func reset() -> void:
	_total_game_minutes = float(DAY_START_MINUTES)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	time_changed.emit()

func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var data: Variant = JSON.parse_string(text)
		if data is Dictionary:
			_total_game_minutes = float(data.get("total_game_minutes", DAY_START_MINUTES))

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"total_game_minutes": _total_game_minutes}))
