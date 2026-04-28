extends Control

# Lists every NPC the pet has formed a bond with. Each entry is a button —
# clicking emits `bond_selected(npc_id)` so FamilyTree can open the detail
# modal for that NPC. Opened from the radial menu's "BOND" item, which only
# appears when the pet has at least one bond.

signal confirmed
signal bond_selected(pet_id: String, npc_id: String)

const FONT := preload("res://assets/fonts/neodgm.ttf")
const NAME_COLOR := Color(0.38, 0.2, 0.26, 1)
const COUNT_COLOR := Color(0.55, 0.35, 0.42, 1)
const DEAD_COLOR := Color(0.55, 0.5, 0.55, 1)

@onready var character_name_label: Label = %CharacterName
@onready var bonds_list: VBoxContainer = %BondsList
@onready var empty_label: Label = %EmptyLabel
@onready var confirm_button: Button = %ConfirmButton

var _viewer_pet_id: String = ""

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false

func show_for(pet: Dictionary) -> void:
	_viewer_pet_id = pet.get("id", "")
	_render(pet)
	visible = true

func _render(pet: Dictionary) -> void:
	character_name_label.text = "%s의 인연" % pet.get("given_name", "")
	for child in bonds_list.get_children():
		child.queue_free()
	var bonds: Dictionary = pet.get("bonds", {})
	if bonds.is_empty():
		empty_label.visible = true
		return
	empty_label.visible = false
	var now: int = int(GameClock._total_game_minutes)
	var entries: Array = []
	for key in bonds.keys():
		var npc_id := String(key)
		var npc := PetStore.find_by_id(npc_id)
		if npc.is_empty():
			continue
		entries.append({
			"id": npc_id,
			"name": String(npc.get("given_name", "")),
			"count": int(bonds[key]),
			"alive": Stats.is_alive(npc, now),
		})
	entries.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	for e in entries:
		bonds_list.add_child(_make_button(e))

func _make_button(entry: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = "  %s   ×%d%s  " % [entry["name"], entry["count"], "" if entry["alive"] else " (사망)"]
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", NAME_COLOR if entry["alive"] else DEAD_COLOR)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("normal", _row_style(false))
	btn.add_theme_stylebox_override("hover", _row_style(true))
	btn.add_theme_stylebox_override("pressed", _row_style(true))
	btn.add_theme_stylebox_override("focus", _row_style(false))
	var npc_id: String = String(entry["id"])
	btn.pressed.connect(func(): _on_bond_pressed(npc_id))
	return btn

func _row_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.984, 0.82, 0.831, 0.85) if active else Color(1, 1, 1, 0.95)
	sb.border_color = Color(0.94, 0.55, 0.62, 1) if active else Color(0.984, 0.82, 0.831, 1)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _on_bond_pressed(npc_id: String) -> void:
	visible = false
	bond_selected.emit(_viewer_pet_id, npc_id)

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()
