extends Control

# Stats-only view of a pet: name, age/lifespan/phase, six stat bars. Holds no
# action UI — that lives in ActModal. Opened via the radial menu's "STAT"
# item.

signal confirmed

const FONT := preload("res://assets/fonts/neodgm.ttf")
const STAT_LABEL_COLOR := Color(0.38, 0.2, 0.26, 1)
const STAT_VALUE_COLOR := Color(0.28, 0.28, 0.34, 1)
const MALE_COLOR := Color(0.30, 0.55, 0.85, 1)
const FEMALE_COLOR := Color(0.92, 0.40, 0.55, 1)

@onready var character_name_label: Label = %CharacterName
@onready var gender_mark: Label = %GenderMark
@onready var age_label: Label = %AgeLabel
@onready var job_label: Label = %JobLabel
@onready var salary_label: Label = %SalaryLabel
@onready var stats_grid: GridContainer = %StatsGrid
@onready var clubs_label: Label = %ClubsLabel
@onready var bonds_label: Label = %BondsLabel
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
	_render(pet)
	visible = true

func _render(pet: Dictionary) -> void:
	character_name_label.text = pet.get("given_name", "")
	_apply_gender_mark(String(pet.get("gender", "")))
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

	_apply_job_label(pet, alive)

	var current := Stats.current_stats(pet, now)
	for k in Stats.KEYS:
		var v: int = int(current.get(k, 0))
		if _stat_bars.has(k):
			_stat_bars[k].value = v
		if _stat_values.has(k):
			_stat_values[k].text = "%d/%d" % [v, Stats.STAT_MAX]

	_apply_clubs_label(pet)
	_apply_bonds_label(pet)

func _apply_job_label(pet: Dictionary, alive: bool) -> void:
	var job_id: Variant = pet.get("job")
	if job_id == null or String(job_id) == "" or not alive:
		job_label.visible = false
		salary_label.visible = false
		return
	var label_text: String = Jobs.label(String(job_id))
	if label_text == "":
		job_label.visible = false
		salary_label.visible = false
		return
	job_label.text = "직업: %s" % label_text
	job_label.visible = true
	salary_label.text = "급여: %d원/s" % Jobs.income_per_second(String(job_id))
	salary_label.visible = true

func _apply_clubs_label(pet: Dictionary) -> void:
	var clubs: Array = pet.get("clubs", [])
	if clubs.is_empty():
		clubs_label.visible = false
		return
	var labels: Array = []
	for id in clubs:
		labels.append(Clubs.label(String(id)))
	clubs_label.text = "동호회: %s" % ", ".join(labels)
	clubs_label.visible = true

func _apply_bonds_label(pet: Dictionary) -> void:
	var bonds: Dictionary = pet.get("bonds", {})
	if bonds.is_empty():
		bonds_label.visible = false
		return
	# Show top 5 bonds by value, descending.
	var entries: Array = bonds.keys().map(func(name): return [String(name), int(bonds[name])])
	entries.sort_custom(func(a, b): return a[1] > b[1])
	var pieces: Array = []
	for e in entries.slice(0, 5):
		pieces.append("%s ×%d" % [e[0], e[1]])
	var more: int = max(0, entries.size() - 5)
	var text: String = "인연: " + ", ".join(pieces)
	if more > 0:
		text += " 외 %d명" % more
	bonds_label.text = text
	bonds_label.visible = true

func _apply_gender_mark(gender: String) -> void:
	match gender:
		"male":
			gender_mark.text = "♂"
			gender_mark.add_theme_color_override("font_color", MALE_COLOR)
			gender_mark.visible = true
		"female":
			gender_mark.text = "♀"
			gender_mark.add_theme_color_override("font_color", FEMALE_COLOR)
			gender_mark.visible = true
		_:
			gender_mark.visible = false

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()
