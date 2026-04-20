extends Control

@onready var body_picker: OptionButton = %BodyPicker
@onready var eyes_picker: OptionButton = %EyesPicker
@onready var color_picker: ColorPickerButton = %ColorPicker
@onready var tama: Tamagotchi = %Tama

func _ready() -> void:
	var ids: Array = Characters.all().map(func(c): return c.get("id", ""))
	ids.sort()
	for id in ids:
		body_picker.add_item(id)
		eyes_picker.add_item(id)

	var default_body := "kuchipatchi"
	var default_eyes := "mametchi"
	_select_id(body_picker, default_body)
	_select_id(eyes_picker, default_eyes)
	color_picker.color = Color.html(Characters.find(default_body).get("color", "#ffffff"))

	body_picker.item_selected.connect(_on_changed)
	eyes_picker.item_selected.connect(_on_changed)
	color_picker.color_changed.connect(func(_c): _apply())

	_apply()

func _select_id(picker: OptionButton, id: String) -> void:
	for i in picker.item_count:
		if picker.get_item_text(i) == id:
			picker.select(i)
			return

func _on_changed(_idx: int) -> void:
	_apply()

func _apply() -> void:
	var body_id := body_picker.get_item_text(body_picker.selected)
	var eyes_id := eyes_picker.get_item_text(eyes_picker.selected)
	tama.set_all(body_id, eyes_id, color_picker.color)
