extends Control

# Action-only view of a pet: shows the catalogue of available actions as
# buttons, overlays a thick donut on the running one, and disables the rest
# while busy. Stats live in StatModal.

signal confirmed

const FONT := preload("res://assets/fonts/neodgm.ttf")
const TEXT_COLOR := Color(0.32, 0.18, 0.24, 1)
const META_COLOR := Color(0.32, 0.18, 0.24, 0.65)
const ROW_HEIGHT := 48.0
const ROW_DONUT_SIZE := 32.0
const ROW_DONUT_THICKNESS := 6.0
const ROW_PADDING_X := 16.0
const ROW_CORNER := 12

@onready var character_name_label: Label = %CharacterName
@onready var actions_list: VBoxContainer = %ActionsList
@onready var empty_label: Label = %EmptyLabel
@onready var confirm_button: Button = %ConfirmButton

var _action_slots: Dictionary = {}
var _current_pet_id: String = ""

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false

func _process(_delta: float) -> void:
	if not visible or _current_pet_id == "":
		return
	var pet := PetStore.find_by_id(_current_pet_id)
	if pet.is_empty() or not Actions.is_busy(pet):
		return
	var rewards := Actions.tick(pet)
	if not rewards.is_empty():
		_render(pet)
	else:
		_refresh_action_states(pet)

func show_for(pet: Dictionary) -> void:
	_current_pet_id = pet.get("id", "")
	_render(pet)
	visible = true

func _render(pet: Dictionary) -> void:
	character_name_label.text = pet.get("given_name", "")
	var now: int = int(GameClock._total_game_minutes)
	var alive := Stats.is_alive(pet, now)
	var proto: Dictionary = PetStore.protagonist()
	var is_protagonist: bool = not proto.is_empty() and pet.get("id", "") == proto.get("id", "")
	var can_act: bool = alive and is_protagonist
	var ids: Array = Actions.available_ids(pet, now) if can_act else []
	var has_actions: bool = not ids.is_empty()
	actions_list.visible = has_actions
	empty_label.visible = not has_actions
	if has_actions:
		_rebuild_actions(pet, now)
	else:
		_action_slots.clear()
		for child in actions_list.get_children():
			child.queue_free()

func _rebuild_actions(pet: Dictionary, now_minutes: int) -> void:
	for child in actions_list.get_children():
		child.queue_free()
	_action_slots.clear()
	var ids: Array = Actions.available_ids(pet, now_minutes)
	for id in ids:
		var action: Dictionary = Actions.CATALOG[id]
		var color: Color = action.get("color", Color(0.95, 0.86, 0.88, 1))

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.add_theme_constant_override("separation", 8)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.text = ""
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_stylebox_override("normal", _row_style(color))
		btn.add_theme_stylebox_override("hover", _row_style(color.lightened(0.08)))
		btn.add_theme_stylebox_override("pressed", _row_style(color.darkened(0.08)))
		btn.add_theme_stylebox_override("focus", _row_style(color))
		btn.add_theme_stylebox_override("disabled", _row_style(_desaturate(color, 0.6)))
		btn.pressed.connect(_on_action_pressed.bind(id))
		row.add_child(btn)

		# The button owns its label/meta as children so the colour fills
		# edge-to-edge while text/meta sit padded inside.
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = ROW_PADDING_X
		content.offset_right = -ROW_PADDING_X
		content.add_theme_constant_override("separation", 12)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(content)

		var name_label := Label.new()
		name_label.add_theme_font_override("font", FONT)
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text = tr(action.label_key)
		content.add_child(name_label)

		var meta_label := Label.new()
		meta_label.add_theme_font_override("font", FONT)
		meta_label.add_theme_font_size_override("font_size", 14)
		meta_label.add_theme_color_override("font_color", META_COLOR)
		meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		meta_label.text = _meta_text(action)
		content.add_child(meta_label)

		var donut_slot := Control.new()
		donut_slot.custom_minimum_size = Vector2(ROW_DONUT_SIZE, ROW_DONUT_SIZE)
		donut_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var donut := DonutProgress.new()
		donut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		donut.thickness = ROW_DONUT_THICKNESS
		donut.fill_color = color.darkened(0.25)
		donut.bg_color = color.lightened(0.15)
		donut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		donut.visible = false
		donut_slot.add_child(donut)
		row.add_child(donut_slot)

		actions_list.add_child(row)
		_action_slots[id] = {"btn": btn, "donut": donut, "name": name_label}
	_refresh_action_states(pet)

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

func _desaturate(color: Color, factor: float) -> Color:
	var grey: float = (color.r + color.g + color.b) / 3.0
	return Color(
		lerp(color.r, grey, factor),
		lerp(color.g, grey, factor),
		lerp(color.b, grey, factor),
		color.a
	)

func _meta_text(action: Dictionary) -> String:
	# School enrollment shows the ongoing per-second cost rather than the
	# enrolment animation length, since the cost is the actually meaningful
	# number for the player.
	var sets_school: String = String(action.get("sets_school", ""))
	if sets_school != "":
		var cost: int = Schools.cost_per_second(sets_school)
		if cost > 0:
			return "초당 -%d원" % cost
		return "무료"
	# Internal `duration` is in game-minutes (1 real second each). Display as
	# the equivalent real-time minutes so "1분/2분/3분" matches what the
	# player actually waits.
	var dur_game_min: int = int(action.get("duration", 0))
	var display_min: int = max(1, int(round(float(dur_game_min) / 60.0)))
	var money: int = int(action.get("money_reward", 0))
	if money > 0:
		return "%d분 · +%d원" % [display_min, money]
	return "%d분" % display_min

func _refresh_action_states(pet: Dictionary) -> void:
	var busy: bool = Actions.is_busy(pet)
	var current_id: String = Actions.active_id(pet)
	var current_progress: float = Actions.progress(pet) if busy else 0.0
	for id in _action_slots:
		var slot: Dictionary = _action_slots[id]
		var btn: Button = slot.btn
		var donut: DonutProgress = slot.donut
		var name_label: Label = slot.name
		var action: Dictionary = Actions.CATALOG[id]
		btn.disabled = busy
		var is_active: bool = id == current_id
		donut.visible = is_active
		if is_active:
			donut.progress = current_progress
			name_label.text = tr(action.get("progress_label_key", action.label_key))
		else:
			name_label.text = tr(action.label_key)

func _on_action_pressed(action_id: String) -> void:
	var pet := PetStore.find_by_id(_current_pet_id)
	if pet.is_empty():
		return
	if not Actions.start(pet, action_id):
		return
	_refresh_action_states(pet)

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()
