extends Control

# Three-way picker for joining a club. Caller invokes `show_for(pet)`; the
# modal grabs three random clubs the pet hasn't joined yet, renders them as
# coloured buttons, and emits `club_chosen(club_id)` when the player picks
# (or `cancelled` if they back out).

signal club_chosen(club_id: String)
signal cancelled

const FONT := preload("res://assets/fonts/neodgm.ttf")
const TEXT_COLOR := Color(0.32, 0.18, 0.24, 1)
const ROW_HEIGHT := 56.0
const ROW_CORNER := 12

@onready var options_list: VBoxContainer = %OptionsList
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel)
	visible = false

func show_for(pet: Dictionary) -> void:
	_clear_options()
	var already: Array = pet.get("clubs", [])
	var picks: Array = Clubs.random_three(already)
	for id in picks:
		_add_option(String(id))
	visible = true

func _clear_options() -> void:
	for child in options_list.get_children():
		child.queue_free()

func _add_option(club_id: String) -> void:
	var color: Color = Clubs.color(club_id)
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _row_style(color))
	btn.add_theme_stylebox_override("hover", _row_style(color.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", _row_style(color.darkened(0.08)))
	btn.add_theme_stylebox_override("focus", _row_style(color))
	btn.pressed.connect(_on_option_pressed.bind(club_id))

	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = Clubs.label(club_id)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)

	options_list.add_child(btn)

func _row_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = ROW_CORNER
	sb.corner_radius_top_right = ROW_CORNER
	sb.corner_radius_bottom_left = ROW_CORNER
	sb.corner_radius_bottom_right = ROW_CORNER
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 1)
	return sb

func _on_option_pressed(club_id: String) -> void:
	visible = false
	club_chosen.emit(club_id)

func _on_cancel() -> void:
	visible = false
	cancelled.emit()
