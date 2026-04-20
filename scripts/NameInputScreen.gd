extends Control

signal confirmed(pet_name: String)

@onready var line_edit: LineEdit = %NameInput
@onready var confirm_button: Button = %ConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirmed)
	line_edit.text_submitted.connect(_on_submitted_via_enter)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		line_edit.text = ""
		line_edit.grab_focus()

# Enter inside a LineEdit on Windows with the Korean IME can fire
# `text_submitted` before the IME finishes committing the last composing
# jamo. Defer one frame so the composition is flushed, then read the final
# text from the widget.
func _on_submitted_via_enter(_t: String) -> void:
	await get_tree().process_frame
	_on_confirmed()

func _on_confirmed() -> void:
	var n := line_edit.text.strip_edges()
	if n.is_empty():
		return
	confirmed.emit(n)
