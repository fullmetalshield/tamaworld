extends Control

signal confirmed(pet_name: String)

@onready var prompt_label: Label = %Prompt
@onready var line_edit: LineEdit = %NameInput
@onready var confirm_button: Button = %ConfirmButton
@onready var recommend_button: Button = %RecommendButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirmed)
	recommend_button.pressed.connect(_on_recommend_pressed)
	line_edit.text_submitted.connect(_on_submitted_via_enter)
	visibility_changed.connect(_on_visibility_changed)

func set_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text

func _on_visibility_changed() -> void:
	if visible:
		line_edit.text = ""
		line_edit.grab_focus()

func _on_recommend_pressed() -> void:
	if PetStore.GIVEN_NAMES.is_empty():
		return
	var n: String = PetStore.GIVEN_NAMES[randi() % PetStore.GIVEN_NAMES.size()]
	line_edit.text = n
	line_edit.caret_column = n.length()
	line_edit.grab_focus()

func _on_submitted_via_enter(_t: String) -> void:
	await get_tree().process_frame
	_on_confirmed()

func _on_confirmed() -> void:
	var n := line_edit.text.strip_edges()
	if n.is_empty():
		return
	confirmed.emit(n)
