extends Control

@onready var main_screen: Control = %MainScreen
@onready var name_input: Control = %NameInputScreen
@onready var tabs: TabContainer = %Tabs

func _ready() -> void:
	main_screen.start_pressed.connect(_on_start_pressed)
	name_input.confirmed.connect(_on_name_confirmed)
	_show_title()

func _show_title() -> void:
	main_screen.visible = true
	name_input.visible = false
	tabs.visible = false

func _show_naming() -> void:
	main_screen.visible = false
	name_input.visible = true
	tabs.visible = false

func _show_tabs() -> void:
	main_screen.visible = false
	name_input.visible = false
	tabs.visible = true

func _on_start_pressed() -> void:
	if PetStore.all().is_empty():
		_show_naming()
	else:
		_show_tabs()

func _on_name_confirmed(pet_name: String) -> void:
	PetStore.create_protagonist(pet_name)
	_show_tabs()
