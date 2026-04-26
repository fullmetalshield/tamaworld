extends Control

# Action-only view of a pet: shows the catalogue of available actions as
# rows, overlays a thick donut on the running one, and disables the rest
# while busy. Stats live in StatModal.
#
# The "club_activity" CATALOG entry is special — it expands into one row per
# joined club (e.g. "독서하기", "축구하기"), with the underlying action id
# remaining "club_activity" and the active_action carrying a `club_id` so
# the right bond pool is tapped on completion. Row keys in `_action_slots`
# are therefore: action_id for normal rows, "club_act:<club_id>" for clubs.

signal confirmed
signal picker_requested(picker_type: String, pet_id: String)

const FONT := preload("res://assets/fonts/neodgm.ttf")
const TEXT_COLOR := Color(0.32, 0.18, 0.24, 1)
const META_COLOR := Color(0.32, 0.18, 0.24, 0.65)
const ROW_HEIGHT := 48.0
const ROW_DONUT_SIZE := 32.0
const ROW_DONUT_THICKNESS := 6.0
const ROW_PADDING_X := 16.0
const ROW_CORNER := 12
const CLUB_ROW_PREFIX := "club_act:"

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
	if pet.is_empty():
		return
	if Actions.is_busy(pet):
		var rewards := Actions.tick(pet)
		if not rewards.is_empty():
			_render(pet)
			return
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
	var rows: Array = _expand_rows(pet, ids)
	var has_rows: bool = not rows.is_empty()
	actions_list.visible = has_rows
	empty_label.visible = not has_rows
	if has_rows:
		_rebuild_actions(pet, rows)
	else:
		_action_slots.clear()
		for child in actions_list.get_children():
			child.queue_free()

# Turns the flat available_ids list into the row descriptors actually shown:
# regular actions stay as-is; the `club_activity` entry is replaced by one
# row per joined club (with that club's flavour label/colour).
func _expand_rows(pet: Dictionary, ids: Array) -> Array:
	var rows: Array = []
	for id in ids:
		if id == "club_activity":
			var template: Dictionary = Actions.CATALOG[id]
			for club_id in pet.get("clubs", []):
				rows.append({
					"row_id": CLUB_ROW_PREFIX + String(club_id),
					"action_id": "club_activity",
					"club_id": String(club_id),
					"label": Clubs.activity_label(String(club_id)),
					"progress_label": Clubs.progress_label(String(club_id)),
					"color": Clubs.color(String(club_id)),
					"template": template,
				})
		else:
			var entry: Dictionary = Actions.CATALOG[id]
			rows.append({
				"row_id": id,
				"action_id": id,
				"club_id": "",
				"label": tr(entry.label_key),
				"progress_label": tr(entry.get("progress_label_key", entry.label_key)),
				"color": entry.get("color", Color(0.95, 0.86, 0.88, 1)),
				"template": entry,
			})
	return rows

func _rebuild_actions(pet: Dictionary, rows: Array) -> void:
	for child in actions_list.get_children():
		child.queue_free()
	_action_slots.clear()
	for row_data in rows:
		var row_id: String = row_data.row_id
		var color: Color = row_data.color
		var template: Dictionary = row_data.template

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
		btn.pressed.connect(_on_row_pressed.bind(row_id))
		row.add_child(btn)

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
		name_label.text = row_data.label
		content.add_child(name_label)

		var meta_label := Label.new()
		meta_label.add_theme_font_override("font", FONT)
		meta_label.add_theme_font_size_override("font_size", 14)
		meta_label.add_theme_color_override("font_color", META_COLOR)
		meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		meta_label.text = _meta_text(template)
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
		_action_slots[row_id] = {
			"btn": btn,
			"donut": donut,
			"name": name_label,
			"meta": meta_label,
			"row_data": row_data,
		}
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
	if String(action.get("opens_picker", "")) != "":
		return "선택지"
	var sets_school: String = String(action.get("sets_school", ""))
	if sets_school != "":
		var cost: int = Schools.cost_per_second(sets_school)
		if cost > 0:
			return "초당 -%d원" % cost
		return "무료"
	var dur_game_min: int = int(action.get("duration", 0))
	var display_min: int = max(1, int(round(float(dur_game_min) / 60.0)))
	var money: int = int(action.get("money_reward", 0))
	if money > 0:
		return "%d분 · +%d원" % [display_min, money]
	return "%d분" % display_min

func _format_cooldown(remaining_game_min: int) -> String:
	if remaining_game_min <= 0:
		return ""
	# Game-min = real-sec at 1:1, so render in real-time units the player
	# actually waits. Sub-minute remainders show as seconds.
	if remaining_game_min < 60:
		return "%d초 후 가능" % remaining_game_min
	var real_min: int = int(round(float(remaining_game_min) / 60.0))
	return "%d분 후 가능" % real_min

# Returns the active row_id (e.g. "play" or "club_act:reading") if the pet
# has an action running, else "".
func _active_row_id(pet: Dictionary) -> String:
	var a: Variant = pet.get("active_action")
	if not (a is Dictionary):
		return ""
	var id: String = String(a.get("id", ""))
	if id == "club_activity":
		var club_id: String = String(a.get("club_id", ""))
		if club_id != "":
			return CLUB_ROW_PREFIX + club_id
	return id

func _refresh_action_states(pet: Dictionary) -> void:
	var busy: bool = Actions.is_busy(pet)
	var active_row: String = _active_row_id(pet)
	var current_progress: float = Actions.progress(pet) if busy else 0.0
	for row_id in _action_slots:
		var slot: Dictionary = _action_slots[row_id]
		var btn: Button = slot.btn
		var donut: DonutProgress = slot.donut
		var name_label: Label = slot.name
		var meta_label: Label = slot.meta
		var row_data: Dictionary = slot.row_data
		var template: Dictionary = row_data.template
		var on_cooldown: bool = false
		var cd_remaining: int = 0
		# Only the underlying action_id carries cooldown state — multiple
		# club rows share the same id but here only "join_club" actually
		# uses cooldowns, so this is unambiguous in practice.
		if int(template.get("cooldown_minutes", 0)) > 0:
			cd_remaining = Actions.cooldown_remaining_minutes(pet, String(row_data.action_id))
			on_cooldown = cd_remaining > 0
		var is_active: bool = row_id == active_row
		btn.disabled = busy or on_cooldown
		donut.visible = is_active
		if is_active:
			donut.progress = current_progress
			name_label.text = row_data.progress_label
			meta_label.text = _meta_text(template)
		else:
			name_label.text = row_data.label
			if on_cooldown:
				meta_label.text = _format_cooldown(cd_remaining)
			else:
				meta_label.text = _meta_text(template)

func _on_row_pressed(row_id: String) -> void:
	var pet := PetStore.find_by_id(_current_pet_id)
	if pet.is_empty():
		return
	var slot: Dictionary = _action_slots.get(row_id, {})
	if slot.is_empty():
		return
	var row_data: Dictionary = slot.row_data
	var action_id: String = String(row_data.action_id)
	var template: Dictionary = row_data.template
	# Picker-style actions don't run as timed waits — open a modal instead.
	var picker: String = String(template.get("opens_picker", ""))
	if picker != "":
		visible = false
		picker_requested.emit(picker, _current_pet_id)
		return
	if action_id == "club_activity":
		if not Actions.start_club_activity(pet, String(row_data.club_id)):
			return
	else:
		if not Actions.start(pet, action_id):
			return
	_refresh_action_states(pet)

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()
