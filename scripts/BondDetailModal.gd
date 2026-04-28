extends Control

# Opened from BondModal when the player clicks a bonded NPC. Shows the NPC's
# appearance, status (job, stats, mutual affection), and the actions the
# viewer can take with them. The NPC themselves is a full pet — they age, hold
# a job, run actions of their own — so the values shown here change over time.

signal confirmed

const FONT := preload("res://assets/fonts/neodgm.ttf")
const NAME_COLOR := Color(0.38, 0.2, 0.26, 1)
const VALUE_COLOR := Color(0.28, 0.28, 0.34, 1)
const FAINT_COLOR := Color(0.55, 0.5, 0.55, 1)
const HEART_COLOR := Color(0.94, 0.55, 0.62, 1)
const MALE_COLOR := Color(0.30, 0.55, 0.85, 1)
const FEMALE_COLOR := Color(0.92, 0.40, 0.55, 1)

const HANGOUT_COOLDOWN_MIN := 120  # 2 game-hours between hangouts
const HANGOUT_BOND_DELTA := 1
const GIFT_COST := 50
const GIFT_BOND_DELTA := 2

@onready var npc_tama: Tamagotchi = %NpcTama
@onready var npc_name_label: Label = %NpcName
@onready var gender_mark: Label = %GenderMark
@onready var age_label: Label = %AgeLabel
@onready var job_label: Label = %JobLabel
@onready var affection_mine: Label = %AffectionMine
@onready var affection_theirs: Label = %AffectionTheirs
@onready var stats_grid: GridContainer = %StatsGrid
@onready var hangout_button: Button = %HangoutButton
@onready var gift_button: Button = %GiftButton
@onready var status_label: Label = %StatusLabel
@onready var confirm_button: Button = %ConfirmButton

var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}
var _stats_built := false

var _viewer_id: String = ""
var _npc_id: String = ""

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	hangout_button.pressed.connect(_on_hangout_pressed)
	gift_button.pressed.connect(_on_gift_pressed)
	visible = false
	_build_stats_grid()

func _build_stats_grid() -> void:
	if _stats_built:
		return
	_stats_built = true
	for child in stats_grid.get_children():
		child.queue_free()
	_stat_bars.clear()
	_stat_values.clear()
	for k in Stats.KEYS:
		var name_label := Label.new()
		name_label.text = Stats.LABELS[k]
		name_label.add_theme_font_override("font", FONT)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", NAME_COLOR)
		stats_grid.add_child(name_label)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = Stats.STAT_MAX
		bar.value = 0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(140, 14)
		stats_grid.add_child(bar)
		_stat_bars[k] = bar

		var value_label := Label.new()
		value_label.text = "0/%d" % Stats.STAT_MAX
		value_label.add_theme_font_override("font", FONT)
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", VALUE_COLOR)
		value_label.custom_minimum_size = Vector2(48, 0)
		stats_grid.add_child(value_label)
		_stat_values[k] = value_label

func show_for(viewer_id: String, npc_id: String) -> void:
	_viewer_id = viewer_id
	_npc_id = npc_id
	status_label.text = ""
	_render()
	visible = true

func _render() -> void:
	var viewer := PetStore.find_by_id(_viewer_id)
	var npc := PetStore.find_by_id(_npc_id)
	if viewer.is_empty() or npc.is_empty():
		visible = false
		return
	var col := Color.html(npc.get("color", "#ffffff"))
	npc_tama.set_all(npc.get("body_id", ""), npc.get("eyes_id", ""), col)
	npc_name_label.text = String(npc.get("given_name", ""))
	_apply_gender_mark(String(npc.get("gender", "")))

	var now: int = int(GameClock._total_game_minutes)
	var alive := Stats.is_alive(npc, now)
	var lifespan_min: int = int(npc.get("lifespan_minutes", Stats.DAY_MINUTES))
	var age_min := Stats.age_minutes(npc, now)
	var phase := Stats.life_phase(age_min, lifespan_min)
	var age_days := age_min / Stats.DAY_MINUTES + 1
	var lifespan_days: int = max(1, int(round(float(lifespan_min) / float(Stats.DAY_MINUTES))))
	if alive:
		age_label.text = "%d일차 / %d일 (%s)" % [age_days, lifespan_days, phase]
		age_label.modulate = Color(1, 1, 1, 1)
	else:
		age_label.text = "사망 (%d일 살았음)" % lifespan_days
		age_label.modulate = FAINT_COLOR

	var job_id: Variant = npc.get("job")
	if alive and job_id != null and Jobs.label(String(job_id)) != "":
		job_label.text = "직업: %s" % Jobs.label(String(job_id))
		job_label.visible = true
	else:
		job_label.visible = false

	var current := Stats.current_stats(npc, now)
	for k in Stats.KEYS:
		var v: int = int(current.get(k, 0))
		if _stat_bars.has(k):
			_stat_bars[k].value = v
		if _stat_values.has(k):
			_stat_values[k].text = "%d/%d" % [v, Stats.STAT_MAX]

	var mine: int = int((viewer.get("bonds", {}) as Dictionary).get(_npc_id, 0))
	var theirs: int = int((npc.get("bonds", {}) as Dictionary).get(_viewer_id, 0))
	affection_mine.text = "내 호감도 ♥ %d" % mine
	affection_theirs.text = "%s의 호감도 ♥ %d" % [String(npc.get("given_name", "")), theirs]

	_refresh_buttons(viewer, alive)

func _refresh_buttons(viewer: Dictionary, npc_alive: bool) -> void:
	if not npc_alive:
		hangout_button.disabled = true
		hangout_button.text = "함께 시간 보내기 (불가)"
		gift_button.disabled = true
		gift_button.text = "선물 주기 (불가)"
		return
	var cd_remaining: int = _hangout_cooldown_remaining(viewer)
	if cd_remaining > 0:
		hangout_button.disabled = true
		hangout_button.text = "함께 시간 보내기 (%d분 후)" % cd_remaining
	else:
		hangout_button.disabled = false
		hangout_button.text = "함께 시간 보내기 (♥ +%d)" % HANGOUT_BOND_DELTA
	if Family.money() < GIFT_COST:
		gift_button.disabled = true
		gift_button.text = "선물 주기 (%d원 부족)" % GIFT_COST
	else:
		gift_button.disabled = false
		gift_button.text = "선물 주기 (-%d원, ♥ +%d)" % [GIFT_COST, GIFT_BOND_DELTA]

func _hangout_cooldown_remaining(viewer: Dictionary) -> int:
	var cd: Dictionary = viewer.get("bond_cooldowns", {})
	var until: int = int(cd.get(_npc_id, 0))
	return max(0, until - int(GameClock._total_game_minutes))

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

func _on_hangout_pressed() -> void:
	var viewer := PetStore.find_by_id(_viewer_id)
	if viewer.is_empty():
		return
	if _hangout_cooldown_remaining(viewer) > 0:
		return
	PetStore.add_bond(_viewer_id, _npc_id, HANGOUT_BOND_DELTA)
	# Stamp cooldown so the player can't immediately click again. We store on
	# the viewer side only — the NPC isn't user-driven so they don't need it.
	var cd: Dictionary = viewer.get("bond_cooldowns", {})
	cd[_npc_id] = int(GameClock._total_game_minutes) + HANGOUT_COOLDOWN_MIN
	viewer["bond_cooldowns"] = cd
	PetStore.persist()
	status_label.text = "함께 즐거운 시간을 보냈습니다. ♥ +%d" % HANGOUT_BOND_DELTA
	_render()

func _on_gift_pressed() -> void:
	if Family.money() < GIFT_COST:
		return
	Family.add_money(-GIFT_COST)
	PetStore.add_bond(_viewer_id, _npc_id, GIFT_BOND_DELTA)
	status_label.text = "선물을 전달했습니다. ♥ +%d" % GIFT_BOND_DELTA
	_render()

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()
