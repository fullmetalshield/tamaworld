extends HBoxContainer

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var home_button: Button = %HomeButton

# Visible money is interpolated toward Family.money() so per-second income
# (jumps of +3, +6, ...) reads as a smooth ticking counter rather than
# discrete jumps. Higher SMOOTH_SPEED = snappier catch-up.
const MONEY_SMOOTH_SPEED := 6.0
var _displayed_money: float = 0.0
var _last_money_text: String = ""

func _ready() -> void:
	GameClock.time_changed.connect(_refresh_clock)
	home_button.pressed.connect(_on_home_pressed)
	_displayed_money = float(Family.money())
	_refresh_clock()
	_render_money(int(round(_displayed_money)))

func _process(delta: float) -> void:
	var target: float = float(Family.money())
	if is_equal_approx(_displayed_money, target):
		return
	var t: float = clampf(MONEY_SMOOTH_SPEED * delta, 0.0, 1.0)
	_displayed_money = lerp(_displayed_money, target, t)
	if absf(target - _displayed_money) < 0.5:
		_displayed_money = target
	_render_money(int(round(_displayed_money)))

func _refresh_clock() -> void:
	day_label.text = GameClock.format_day()
	time_label.text = GameClock.format_time()

func _render_money(value: int) -> void:
	var text: String = tr("HUD_MONEY") % value
	if text == _last_money_text:
		return
	_last_money_text = text
	money_label.text = text

func _on_home_pressed() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("_show_title"):
		main._show_title()
