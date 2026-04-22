extends Control

signal confirmed

const FONT := preload("res://assets/fonts/neodgm.ttf")
const STAT_LABEL_COLOR := Color(0.38, 0.2, 0.26, 1)
const STAT_VALUE_COLOR := Color(0.28, 0.28, 0.34, 1)

@onready var character_name_label: Label = %CharacterName
@onready var age_label: Label = %AgeLabel
@onready var stats_grid: GridContainer = %StatsGrid
@onready var confirm_button: Button = %ConfirmButton

var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}
var _built := false

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false
	_build_stats_grid()

func _build_stats_grid() -> void:
	if _built:
		return
	_built = true
	for child in stats_grid.get_children():
		child.queue_free()
	_stat_bars.clear()
	_stat_values.clear()
	for k in Stats.KEYS:
		var name_label := Label.new()
		name_label.text = Stats.LABELS[k]
		name_label.add_theme_font_override("font", FONT)
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", STAT_LABEL_COLOR)
		stats_grid.add_child(name_label)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = Stats.STAT_MAX
		bar.value = 0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(180, 16)
		stats_grid.add_child(bar)
		_stat_bars[k] = bar

		var value_label := Label.new()
		value_label.text = "0/%d" % Stats.STAT_MAX
		value_label.add_theme_font_override("font", FONT)
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", STAT_VALUE_COLOR)
		value_label.custom_minimum_size = Vector2(56, 0)
		stats_grid.add_child(value_label)
		_stat_values[k] = value_label

func show_for(pet: Dictionary) -> void:
	character_name_label.text = pet.get("given_name", "")
	var now: int = int(GameClock._total_game_minutes)
	var age_min := Stats.age_minutes(pet, now)
	var lifespan_min: int = int(pet.get("lifespan_minutes", Stats.DAY_MINUTES))
	var alive := Stats.is_alive(pet, now)
	var phase := Stats.life_phase(age_min, lifespan_min)
	var age_days := age_min / Stats.DAY_MINUTES + 1
	var lifespan_days: int = max(1, int(round(float(lifespan_min) / float(Stats.DAY_MINUTES))))
	if alive:
		age_label.text = "%d일차 / %d일 (%s)" % [age_days, lifespan_days, phase]
		age_label.modulate = Color(1, 1, 1, 1)
	else:
		age_label.text = "사망 (%d일 살았음)" % lifespan_days
		age_label.modulate = Color(0.55, 0.5, 0.55, 1)

	var current := Stats.current_stats(pet, now)
	for k in Stats.KEYS:
		var v: int = int(current.get(k, 0))
		if _stat_bars.has(k):
			_stat_bars[k].value = v
		if _stat_values.has(k):
			_stat_values[k].text = "%d/%d" % [v, Stats.STAT_MAX]
	visible = true

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()
