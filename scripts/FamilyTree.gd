extends Control

const FONT := preload("res://assets/fonts/neodgm.ttf")
const SLOT_INDICATOR_DONUT_SIZE := 18.0
const SLOT_INDICATOR_DONUT_THICKNESS := 6.0
const SLOT_INDICATOR_TEXT_COLOR := Color(0.38, 0.2, 0.26, 1)

var _slot_indicators: Dictionary = {}

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
@onready var stat_modal: Control = %StatModal
@onready var act_modal: Control = %ActModal
@onready var club_picker_modal: Control = %ClubPickerModal
@onready var child_birth_modal: Control = %ChildBirthModal
@onready var bond_modal: Control = %BondModal
@onready var bond_detail_modal: Control = %BondDetailModal

var _radial_menu: RadialMenu
var _radial_pet_id: String = ""
var _elevated_slot: Control = null
var _elevated_slot_z: int = 0
var _elevated_name: Label = null
var _elevated_indicator: Control = null
const _ELEVATED_Z := 100
const _NAME_FADE_DURATION := 0.12
# Radial menu sits slightly below the slot's geometric centre so it ends up
# visually centred on the character's body (which renders mostly in the
# upper-middle of the slot). Screen-space offset, so it stays consistent
# regardless of zoom.
const _RADIAL_CENTER_OFFSET := Vector2(0, 10)

const _CLICK_DRAG_THRESHOLD := 6.0
# Visual nudge for the initial centering — protagonist sits 50px above the
# geometric viewport centre so children below have room to come into view.
const _PROTAGONIST_VIEW_OFFSET := Vector2(0, -50)
var _slot_press_origin := Vector2.ZERO
var _slot_pressed: Control = null

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
	EventManager.child_naming_requested.connect(_on_child_naming_requested)
	EventManager.child_born.connect(_on_child_born)
	child_birth_modal.confirmed.connect(_on_child_birth_confirmed)
	act_modal.picker_requested.connect(_on_picker_requested)
	club_picker_modal.club_chosen.connect(_on_club_chosen)
	club_picker_modal.cancelled.connect(_on_picker_cancelled)
	bond_modal.bond_selected.connect(_on_bond_selected)
	visibility_changed.connect(_on_visibility_changed)

	stage_viewport.gui_input.connect(_on_stage_input)
	stage_viewport.resized.connect(_on_viewport_resized)
	zoom_slider.value_changed.connect(_on_zoom_slider_changed)

	var slot1 := stage_canvas.get_node("Slot1") as Control
	slot1.gui_input.connect(_on_slot_input.bind(1))
	slot2.gui_input.connect(_on_slot_input.bind(2))
	slot3.gui_input.connect(_on_slot_input.bind(3))

	event_banner.visible = false
	slot2.visible = false
	slot3.visible = false
	child_birth_modal.visible = false
	_build_slot_indicators()
	_build_radial_menu()
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
	var pending_child := EventManager.pending_child()
	if not pending_child.is_empty():
		child_birth_modal.show_for(pending_child)

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

func _process(_delta: float) -> void:
	_refresh_slot_indicators()

# --- radial menu --------------------------------------------------------

func _build_radial_menu() -> void:
	if _radial_menu != null:
		return
	_radial_menu = RadialMenu.new()
	add_child(_radial_menu)
	_radial_menu.item_selected.connect(_on_radial_item_selected)
	_radial_menu.closed.connect(_restore_slot)

func _elevate_slot(slot_index: int) -> void:
	# Lift the clicked character above the radial menu's backdrop so it
	# remains bright and visibly "the target", while everything else dims.
	# Fade out the floating name and the slot's action indicator so only
	# the character image is on display while the menu is up.
	_restore_slot()
	var slot := _get_slot(slot_index)
	if slot == null:
		return
	_elevated_slot = slot
	_elevated_slot_z = slot.z_index
	slot.z_index = _ELEVATED_Z

	var name_label := _name_for_slot(slot_index)
	if name_label != null:
		_elevated_name = name_label
		var tw_n := create_tween()
		tw_n.tween_property(name_label, "modulate:a", 0.0, _NAME_FADE_DURATION)

	var indicator: Dictionary = _slot_indicators.get(slot_index, {})
	if not indicator.is_empty():
		var container: Control = indicator.container
		_elevated_indicator = container
		var tw_i := create_tween()
		tw_i.tween_property(container, "modulate:a", 0.0, _NAME_FADE_DURATION)

func _restore_slot() -> void:
	if _elevated_slot != null and is_instance_valid(_elevated_slot):
		_elevated_slot.z_index = _elevated_slot_z
	_elevated_slot = null
	if _elevated_name != null and is_instance_valid(_elevated_name):
		var tw_n := create_tween()
		tw_n.tween_property(_elevated_name, "modulate:a", 1.0, _NAME_FADE_DURATION)
	_elevated_name = null
	if _elevated_indicator != null and is_instance_valid(_elevated_indicator):
		var tw_i := create_tween()
		tw_i.tween_property(_elevated_indicator, "modulate:a", 1.0, _NAME_FADE_DURATION)
	_elevated_indicator = null

func _name_for_slot(slot_index: int) -> Label:
	match slot_index:
		1: return floating_name1
		2: return floating_name2
		3: return floating_name3
	return null

func _open_radial_for_pet(pet: Dictionary, slot_index: int) -> void:
	var slot := _get_slot(slot_index)
	if slot == null:
		return
	_radial_pet_id = pet.get("id", "")
	var proto := PetStore.protagonist()
	var is_protagonist: bool = not proto.is_empty() and pet.get("id", "") == proto.get("id", "")
	var now: int = int(GameClock._total_game_minutes)
	var alive := Stats.is_alive(pet, now)
	var items: Array = [{"id": "stat", "label": tr("RADIAL_STAT")}]
	if is_protagonist and alive:
		items.append({"id": "act", "label": tr("RADIAL_ACT")})
	var bonds: Dictionary = pet.get("bonds", {})
	if not bonds.is_empty():
		items.append({"id": "bond", "label": tr("RADIAL_BOND")})
	_elevate_slot(slot_index)
	# Use the full transform chain so zoom/pan are honoured — `get_global_rect`
	# alone returns the unscaled local size, which would mis-centre the menu
	# whenever the StageCanvas isn't at zoom 1.0.
	var center: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5) + _RADIAL_CENTER_OFFSET
	_radial_menu.open_at(center, items)

var _picker_pet_id: String = ""

func _on_picker_requested(picker_type: String, pet_id: String) -> void:
	_picker_pet_id = pet_id
	var pet := PetStore.find_by_id(pet_id)
	if pet.is_empty():
		return
	match picker_type:
		"club":
			club_picker_modal.show_for(pet)

func _on_club_chosen(club_id: String) -> void:
	var pet := PetStore.find_by_id(_picker_pet_id)
	if pet.is_empty():
		return
	var clubs: Array = pet.get("clubs", [])
	if not (club_id in clubs):
		clubs.append(club_id)
		pet["clubs"] = clubs
		PetStore.persist()
	# Cooldown stamps go on the pet so the same picker can't be re-fired
	# until enough game-minutes have elapsed.
	Actions.set_cooldown(pet, "join_club")
	# Reopen ActModal so the player sees the new club-specific activity.
	act_modal.show_for(pet)

func _on_bond_selected(viewer_id: String, npc_id: String) -> void:
	bond_detail_modal.show_for(viewer_id, npc_id)

func _on_picker_cancelled() -> void:
	# Reopen the action list so the player can pick something else.
	var pet := PetStore.find_by_id(_picker_pet_id)
	if not pet.is_empty():
		act_modal.show_for(pet)

func _on_radial_item_selected(id: String) -> void:
	# Restore z_index immediately so the modal that follows can dim the
	# character along with everything else (otherwise the elevated slot
	# would float above the modal backdrop too).
	_restore_slot()
	var pet := PetStore.find_by_id(_radial_pet_id)
	if pet.is_empty():
		return
	match id:
		"stat":
			stat_modal.show_for(pet)
		"act":
			act_modal.show_for(pet)
		"bond":
			bond_modal.show_for(pet)

# --- per-slot action indicator -----------------------------------------

func _build_slot_indicators() -> void:
	var slot1 := stage_canvas.get_node("Slot1") as Control
	_slot_indicators[1] = _make_slot_indicator(slot1)
	_slot_indicators[2] = _make_slot_indicator(slot2)
	_slot_indicators[3] = _make_slot_indicator(slot3)

func _make_slot_indicator(slot: Control) -> Dictionary:
	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 4)
	# Bottom-center of the slot, hanging just below the character.
	container.anchor_left = 0.0
	container.anchor_right = 1.0
	container.anchor_top = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = 0.0
	container.offset_right = 0.0
	container.offset_top = -4.0
	container.offset_bottom = 22.0
	container.visible = false

	var donut := DonutProgress.new()
	donut.custom_minimum_size = Vector2(SLOT_INDICATOR_DONUT_SIZE, SLOT_INDICATOR_DONUT_SIZE)
	donut.thickness = SLOT_INDICATOR_DONUT_THICKNESS
	donut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(donut)

	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SLOT_INDICATOR_TEXT_COLOR)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	slot.add_child(container)
	return {"donut": donut, "label": label, "container": container}

func _refresh_slot_indicators() -> void:
	var proto := PetStore.protagonist()
	if proto.is_empty():
		for idx in _slot_indicators:
			_slot_indicators[idx].container.visible = false
		return
	_apply_slot_indicator(1, proto)
	_apply_slot_indicator(2, PetStore.spouse_of(proto))
	var kids := PetStore.children_of(proto)
	_apply_slot_indicator(3, kids[0] if not kids.is_empty() else {})

func _apply_slot_indicator(slot_index: int, pet: Dictionary) -> void:
	var ind: Dictionary = _slot_indicators.get(slot_index, {})
	if ind.is_empty():
		return
	if pet.is_empty() or not Actions.is_busy(pet):
		ind.container.visible = false
		return
	var action_id := Actions.active_id(pet)
	if not Actions.CATALOG.has(action_id):
		ind.container.visible = false
		return
	var action: Dictionary = Actions.CATALOG[action_id]
	ind.container.visible = true
	ind.donut.progress = Actions.progress(pet)
	ind.label.text = tr(action.get("progress_label_key", action.label_key))

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

# --- slot click ---------------------------------------------------------

func _on_slot_input(event: InputEvent, slot_index: int) -> void:
	# Distinguish a click from a drag by tracking how far the mouse moved
	# between press and release.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_slot_pressed = _get_slot(slot_index)
			_slot_press_origin = event.global_position
		else:
			var pressed := _slot_pressed
			_slot_pressed = null
			if pressed == null or pressed != _get_slot(slot_index):
				return
			if event.global_position.distance_to(_slot_press_origin) > _CLICK_DRAG_THRESHOLD:
				return
			var pet := _pet_for_slot(slot_index)
			if pet.is_empty():
				return
			_open_radial_for_pet(pet, slot_index)

func _get_slot(slot_index: int) -> Control:
	match slot_index:
		1: return stage_canvas.get_node("Slot1") as Control
		2: return slot2
		3: return slot3
		_: return null

func _pet_for_slot(slot_index: int) -> Dictionary:
	var proto := PetStore.protagonist()
	if proto.is_empty():
		return {}
	match slot_index:
		1:
			return proto
		2:
			return PetStore.spouse_of(proto)
		3:
			var kids := PetStore.children_of(proto)
			return kids[0] if not kids.is_empty() else {}
	return {}

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
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return  # Layout not yet computed; resized signal will retry.
	# Account for current zoom: scaled slot centre lives at (slot_centre * zoom)
	# from canvas top-left when pivot_offset == (0, 0). With pivot at canvas
	# centre, scaling pulls everything toward that pivot; we just need the
	# screen-space centre to match.
	var slot1_centre: Vector2 = slot1.position + slot1.size * 0.5
	# With pivot_offset = stage_canvas.size/2 and scale = z:
	# screen_pos(slot1_centre) = stage_canvas.position + canvas_size/2 + (slot1_centre - canvas_size/2) * z
	# We want screen_pos = viewport_size/2.
	var canvas_half: Vector2 = stage_canvas.size * 0.5
	_canvas_base = viewport_size * 0.5 - canvas_half - (slot1_centre - canvas_half) * _zoom + _PROTAGONIST_VIEW_OFFSET
	_pan = Vector2.ZERO

func _apply_transform() -> void:
	if stage_canvas == null:
		return
	stage_canvas.scale = Vector2(_zoom, _zoom)
	stage_canvas.pivot_offset = stage_canvas.size * 0.5
	stage_canvas.position = _canvas_base + _pan

# --- event handlers -----------------------------------------------------

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	_refresh()
	# `resized` signal handles centering once layout settles. We also try once
	# here in case the viewport already had a size from a previous show.
	_center_on_protagonist()
	_apply_transform()

func _on_viewport_resized() -> void:
	# Re-center only if the user hasn't manually panned/zoomed yet — that way
	# user adjustments are preserved across resizes.
	if _pan != Vector2.ZERO or not is_equal_approx(_zoom, 1.0):
		return
	_center_on_protagonist()
	_apply_transform()

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

func _on_child_naming_requested(pending_child: Dictionary) -> void:
	child_birth_modal.show_for(pending_child)

func _on_child_birth_confirmed(child_name: String) -> void:
	EventManager.confirm_child_birth(child_name)

func _on_child_born(_child: Dictionary) -> void:
	# No banner here — birth is announced via the naming modal itself.
	_refresh()

func _on_reset_pressed() -> void:
	PetStore.reset()
	EventManager.reset()
	GameClock.reset()
	Family.reset()
	event_banner.visible = false
	_zoom = 1.0
	zoom_slider.set_value_no_signal(1.0)
	_center_on_protagonist()
	_apply_transform()
	_refresh()
	var main = get_tree().current_scene
	if main != null and main.has_method("_show_naming"):
		main._show_naming()
