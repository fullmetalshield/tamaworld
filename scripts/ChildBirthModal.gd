extends Control

signal confirmed(pet_name: String)

@onready var child_tama: Tamagotchi = %ChildTama
@onready var name_input: LineEdit = %ChildNameInput
@onready var recommend_button: Button = %ChildRecommendButton
@onready var confirm_button: Button = %ChildConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	recommend_button.pressed.connect(_on_recommend_pressed)
	name_input.text_submitted.connect(_on_submitted_via_enter)
	visibility_changed.connect(_on_visibility_changed)
	visible = false

func show_for(pet: Dictionary) -> void:
	var col := Color.html(pet.get("color", "#ffffff"))
	child_tama.set_all(pet.get("body_id", ""), pet.get("eyes_id", ""), col)
	visible = true

func _on_visibility_changed() -> void:
	if visible:
		name_input.text = ""
		name_input.grab_focus()

func _on_recommend_pressed() -> void:
	if PetStore.GIVEN_NAMES.is_empty():
		return
	var n: String = PetStore.GIVEN_NAMES[randi() % PetStore.GIVEN_NAMES.size()]
	name_input.text = n
	name_input.caret_column = n.length()
	name_input.grab_focus()

func _on_submitted_via_enter(_t: String) -> void:
	await get_tree().process_frame
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	var n := name_input.text.strip_edges()
	if n.is_empty():
		return
	visible = false
	confirmed.emit(n)
