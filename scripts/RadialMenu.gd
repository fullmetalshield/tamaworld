class_name RadialMenu
extends Control

# Pop-up menu that fans items around a target screen position.
# Items are passed as `[{"id": String, "label": String}, ...]`. They start
# stacked at the centre with scale 0 and tween outward to a point on a
# circle, evenly distributed (TAU / n). With 6 items the layout naturally
# becomes a hexagon. A semi-transparent backdrop catches clicks outside the
# menu so any click-away dismisses it.

signal item_selected(id: String)
signal closed

const FONT := preload("res://assets/fonts/neodgm.ttf")
const ITEM_SIZE := Vector2(72, 72)
const RADIUS := 130.0
const OPEN_DURATION := 0.28
const CLOSE_DURATION := 0.14
const STAGGER := 0.035

var _backdrop: ColorRect
var _items_layer: Control
var _items: Array = []
var _open: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.22)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_items_layer = Control.new()
	_items_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_items_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_items_layer)

func open_at(global_center: Vector2, items: Array) -> void:
	_clear_items()
	if items.is_empty():
		return
	visible = true
	_open = true
	# Convert the slot's screen-space centre into our local space so items
	# land exactly on the character regardless of where this overlay sits.
	var local_center: Vector2 = _items_layer.get_global_transform_with_canvas().affine_inverse() * global_center
	var n: int = items.size()
	for i in n:
		var data: Dictionary = items[i]
		var btn := _make_item_button(data)
		_items_layer.add_child(btn)
		_items.append(btn)
		btn.size = ITEM_SIZE
		btn.pivot_offset = ITEM_SIZE * 0.5
		btn.position = local_center - ITEM_SIZE * 0.5
		btn.scale = Vector2.ZERO
		var angle: float = -PI * 0.5 + TAU * float(i) / float(n)
		var target: Vector2 = local_center + Vector2(cos(angle), sin(angle)) * RADIUS - ITEM_SIZE * 0.5
		var t := create_tween().set_parallel(true)
		t.tween_property(btn, "position", target, OPEN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * STAGGER)
		t.tween_property(btn, "scale", Vector2.ONE, OPEN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * STAGGER)

func close() -> void:
	if not _open:
		return
	_open = false
	var snapshot := _items.duplicate()
	_items.clear()
	if snapshot.is_empty():
		visible = false
		closed.emit()
		return
	var t := create_tween().set_parallel(true)
	for btn in snapshot:
		if not is_instance_valid(btn):
			continue
		t.tween_property(btn, "scale", Vector2.ZERO, CLOSE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func():
		for btn in snapshot:
			if is_instance_valid(btn):
				btn.queue_free()
		visible = false
		closed.emit()
	)

func _clear_items() -> void:
	for btn in _items:
		if is_instance_valid(btn):
			btn.queue_free()
	_items.clear()

func _make_item_button(data: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = String(data.get("label", ""))
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.38, 0.2, 0.26, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _normal_style())
	btn.add_theme_stylebox_override("hover", _hover_style())
	btn.add_theme_stylebox_override("pressed", _hover_style())
	btn.add_theme_stylebox_override("focus", _normal_style())
	var id: String = String(data.get("id", ""))
	btn.pressed.connect(_on_item_pressed.bind(id))
	return btn

func _normal_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.96)
	sb.border_color = Color(0.984, 0.82, 0.831, 1)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	var r := int(ITEM_SIZE.x * 0.5)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6
	return sb

func _hover_style() -> StyleBoxFlat:
	var sb := _normal_style()
	sb.bg_color = Color(0.984, 0.82, 0.831, 1)
	sb.border_color = Color(0.94, 0.55, 0.62, 1)
	return sb

func _on_item_pressed(id: String) -> void:
	item_selected.emit(id)
	close()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()
