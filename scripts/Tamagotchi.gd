class_name Tamagotchi
extends Node2D

const CANVAS_SIZE := Vector2(230, 236)
const ASSET_ROOT := "res://assets/tamagotchi"
const BODY_SHADER := preload("res://shaders/body.gdshader")
const OVERLAY_SHADER := preload("res://shaders/overlay.gdshader")
const SOFT_LIGHT_SHADER := preload("res://shaders/soft_light.gdshader")

@export var body_id: String = ""
@export var eyes_id: String = ""
@export var body_color: Color = Color(1, 1, 1, 1)

var _layer_root: Node2D

func _ready() -> void:
	_layer_root = Node2D.new()
	_layer_root.name = "Layers"
	add_child(_layer_root)
	rebuild()

func set_all(new_body: String, new_eyes: String, new_color: Color) -> void:
	body_id = new_body
	eyes_id = new_eyes
	body_color = new_color
	rebuild()

func rebuild() -> void:
	if _layer_root == null:
		return
	for child in _layer_root.get_children():
		child.queue_free()

	if body_id == "" or eyes_id == "":
		return

	var body_data := Characters.find(body_id)
	var eyes_data := Characters.find(eyes_id)
	if body_data.is_empty() or eyes_data.is_empty():
		push_warning("Unknown character id: body=%s eyes=%s" % [body_id, eyes_id])
		return

	var field: String = body_data.get("field", "")

	# Body first: its shader replaces opaque-white with transparent and fills
	# transparent interior pixels with body_color, giving shadow/highlight
	# a proper base to blend against via screen_texture.
	var body_mat := ShaderMaterial.new()
	body_mat.shader = BODY_SHADER
	body_mat.set_shader_parameter("body_color", body_color)
	_add_sprite("%s/%s/%s-body.png" % [ASSET_ROOT, field, body_id], Vector2.ZERO, body_mat)

	if body_data.get("hasShadow", false):
		_add_sprite("%s/%s/%s-shadow.png" % [ASSET_ROOT, field, body_id], Vector2.ZERO, _shader_mat(OVERLAY_SHADER))
	if body_data.get("hasHighlight", false):
		_add_sprite("%s/%s/%s-highlight.png" % [ASSET_ROOT, field, body_id], Vector2.ZERO, _shader_mat(SOFT_LIGHT_SHADER))

	var body_eye: Vector2 = Characters.eye_position(body_id)
	var eyes_origin: Vector2 = Characters.eye_position(eyes_id)
	var eyes_pos := body_eye - eyes_origin
	var eyes_field: String = eyes_data.get("field", "")
	_add_sprite("%s/%s/%s-eyes.png" % [ASSET_ROOT, eyes_field, eyes_id], eyes_pos)

	if body_data.get("hasMouth", false):
		_add_sprite("%s/%s/%s-mouth.png" % [ASSET_ROOT, field, body_id], Vector2.ZERO)

func _shader_mat(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _add_sprite(texture_path: String, pos: Vector2, material: Material = null) -> Sprite2D:
	var tex: Texture2D = load(texture_path)
	if tex == null:
		push_warning("Missing texture: %s" % texture_path)
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	if material != null:
		s.material = material
	_layer_root.add_child(s)
	return s
