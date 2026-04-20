extends Control

@onready var tama1: Tamagotchi = %Tama1
@onready var tama2: Tamagotchi = %Tama2
@onready var tama3: Tamagotchi = %Tama3
@onready var slot2: Control = %Slot2
@onready var slot3: Control = %Slot3
@onready var floating_name1: Label = %FloatingName1
@onready var floating_name2: Label = %FloatingName2
@onready var floating_name3: Label = %FloatingName3
@onready var reset_button: Button = %ResetButton

@onready var stage_viewport: Panel = %StageViewport
@onready var stage_canvas: Control = %StageCanvas
@onready var zoom_slider: VSlider = %ZoomSlider

@onready var event_banner: PanelContainer = %EventBanner
@onready var event_banner_label: Label = %EventBannerLabel
@onready var event_banner_accept: Button = %EventBannerAccept

var _zoom := 1.0
var _pan := Vector2.ZERO
var _canvas_base: Vector2 = Vector2.ZERO
var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pan := Vector2.ZERO

func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	event_banner_accept.pressed.connect(_on_accept_partner)
	EventManager.partner_candidate_appeared.connect(_on_partner_candidate)
	EventManager.child_born.connect(_on_child_born)
	visibility_changed.connect(_on_visibility_changed)

	stage_viewport.gui_input.connect(_on_stage_input)
	zoom_slider.value_changed.connect(_on_zoom_slider_changed)

	event_banner.visible = false
	slot2.visible = false
	slot3.visible = false
	_refresh()
	await get_tree().process_frame
	_center_on_protagonist()
	_apply_transform()
	_start_name_bob(floating_name1, 0.0)
	_start_name_bob(floating_name2, 0.3)
	_start_name_bob(floating_name3, 0.6)

	var pending := EventManager.partner_candidate()
	if not pending.is_empty() and PetStore.protagonist().get("spouse_id") == null:
		_show_partner_banner(pending)

func _refresh() -> void:
	var proto := PetStore.protagonist()
	if proto.is_empty():
		_clear_slot(tama1, floating_name1)
		_clear_slot(tama2, floating_name2)
		_clear_slot(tama3, floating_name3)
		slot2.visible = false
		slot3.visible = false
		return
	_apply_pet(proto, tama1, floating_name1)

	var spouse := PetStore.spouse_of(proto)
	if spouse.is_empty():
		slot2.visible = false
		_clear_slot(tama2, floating_name2)
	else:
		slot2.visible = true
		_apply_pet(spouse, tama2, floating_name2)

	var kids := PetStore.children_of(proto)
	if kids.is_empty():
		slot3.visible = false
		_clear_slot(tama3, floating_name3)
	else:
		slot3.visible = true
		_apply_pet(kids[0], tama3, floating_name3)

func _apply_pet(pet: Dictionary, t: Tamagotchi, n: Label) -> void:
	var col := Color.html(pet.get("color", "#ffffff"))
	t.set_all(pet.get("body_id", ""), pet.get("eyes_id", ""), col)
	n.text = pet.get("given_name", "")

func _clear_slot(t: Tamagotchi, n: Label) -> void:
	n.text = ""
	t.set_all("", "", Color.WHITE)

# --- floating name bob --------------------------------------------------

func _start_name_bob(label: Label, phase_delay: float) -> void:
	var base_y := label.position.y
	var tween := create_tween().set_loops().bind_node(self)
	if phase_delay > 0.0:
		tween.tween_interval(phase_delay)
	tween.tween_property(label, "position:y", base_y - 5.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "position:y", base_y, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- pan / zoom ---------------------------------------------------------

func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(_zoom * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(_zoom / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if _dragging:
				_drag_start_mouse = event.position
				_drag_start_pan = _pan
	elif event is InputEventMouseMotion and _dragging:
		_pan = _drag_start_pan + (event.position - _drag_start_mouse)
		_apply_transform()

func _on_zoom_slider_changed(v: float) -> void:
	if is_equal_approx(v, _zoom):
		return
	_zoom = v
	_apply_transform()

func _set_zoom(z: float) -> void:
	_zoom = clamp(z, zoom_slider.min_value, zoom_slider.max_value)
	zoom_slider.set_value_no_signal(_zoom)
	_apply_transform()

func _center_on_protagonist() -> void:
	# StageCanvas is top-left anchored; we place it so Slot1 sits at the
	# viewport centre, then apply user `_pan` on top.
	var slot1 := stage_canvas.get_node_or_null("Slot1") as Control
	if slot1 == null:
		return
	var viewport_size: Vector2 = stage_viewport.size
	var slot1_centre: Vector2 = slot1.position + slot1.size * 0.5
	_canvas_base = viewport_size * 0.5 - slot1_centre
	_pan = Vector2.ZERO

func _apply_transform() -> void:
	if stage_canvas == null:
		return
	stage_canvas.scale = Vector2(_zoom, _zoom)
	stage_canvas.pivot_offset = stage_canvas.size * 0.5
	stage_canvas.position = _canvas_base + _pan

# --- event handlers -----------------------------------------------------

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()

func _on_partner_candidate(partner: Dictionary) -> void:
	_show_partner_banner(partner)

func _show_partner_banner(partner: Dictionary) -> void:
	event_banner.visible = true
	event_banner_accept.visible = true
	event_banner_accept.text = "결혼하기"
	event_banner_label.text = "결혼할 상대가 나타났습니다! %s" % partner.get("given_name", "")

func _on_accept_partner() -> void:
	EventManager.accept_partner()
	event_banner.visible = false
	_refresh()

func _on_child_born(child: Dictionary) -> void:
	event_banner.visible = true
	event_banner_accept.visible = false
	event_banner_label.text = "자녀가 태어났습니다! %s" % child.get("given_name", "")
	_refresh()
	await get_tree().create_timer(3.0).timeout
	if not event_banner_accept.visible:
		event_banner.visible = false

func _on_reset_pressed() -> void:
	PetStore.reset()
	EventManager.reset()
	event_banner.visible = false
	_zoom = 1.0
	zoom_slider.set_value_no_signal(1.0)
	_center_on_protagonist()
	_apply_transform()
	_refresh()
	var main = get_tree().current_scene
	if main != null and main.has_method("_show_naming"):
		main._show_naming()
