extends HBoxContainer

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var home_button: Button = %HomeButton

func _ready() -> void:
	GameClock.time_changed.connect(_refresh)
	home_button.pressed.connect(_on_home_pressed)
	_refresh()

func _refresh() -> void:
	day_label.text = GameClock.format_day()
	time_label.text = GameClock.format_time()

func _on_home_pressed() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("_show_title"):
		main._show_title()
