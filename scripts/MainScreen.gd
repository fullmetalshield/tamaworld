extends Control

signal start_pressed

const LOGO_PATH := "res://assets/images/main.png"
const DECO_SPRITE_PATH := "res://assets/images/image.png"
const DECO_CELL_SIZE := 202  # 607 / 3 sprite grid
const DECO_DISPLAY_SIZE := 64

# Each atlas index (0..8) is used exactly once — no duplicates.
# 6 decorations cluster around the title, 3 around the button.
const DECO_LAYOUT_TITLE := [
	[8, Vector2(60, -10), -12.0],
	[4, Vector2(180, -25), 10.0],     # centre-top A
	[5, Vector2(300, -25), -6.0],     # centre-top B
	[3, Vector2(420, -10), 12.0],
	[1, Vector2(-30, 55), -10.0],     # left middle
	[2, Vector2(510, 55), 14.0],      # right middle
]

# Button cluster: local to StartButton (358x124).
const DECO_LAYOUT_BUTTON := [
	[0, Vector2(179, -40), 12.0],     # above button centre
	[6, Vector2(-40, 60), -15.0],     # left
	[7, Vector2(398, 60), 12.0],      # right
]

@onready var logo_rect: TextureRect = %LogoRect
@onready var fallback_label: Label = %FallbackLabel
@onready var start_button: BaseButton = %StartButton

# Per-decoration motion params. Each axis (x, y, rotation) has its own
# amplitude, period, and phase so the motion is a gentle Lissajous rather
# than a plain up/down bob.
var _decorations: Array = []

func _ready() -> void:
	var has_logo := ResourceLoader.exists(LOGO_PATH)
	logo_rect.visible = has_logo
	fallback_label.visible = not has_logo
	start_button.pressed.connect(func(): start_pressed.emit())
	_spawn_decorations()

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for d in _decorations:
		var rect: TextureRect = d.rect
		if not is_instance_valid(rect):
			continue
		# Matched x/y period with a 90° phase offset → gentle ellipse orbit
		# around the base position, keeping each decoration visually anchored.
		var angle: float = t * TAU / float(d.period) + float(d.phase)
		var dx: float = cos(angle) * float(d.amp_x)
		var dy: float = sin(angle) * float(d.amp_y)
		var dr: float = sin(t * TAU / float(d.period_rot) + float(d.phase_rot)) * float(d.amp_rot)
		rect.position = d.base_pos + Vector2(dx, dy)
		rect.rotation = d.base_rot + dr

func _spawn_decorations() -> void:
	if not ResourceLoader.exists(DECO_SPRITE_PATH):
		return
	var tex: Texture2D = load(DECO_SPRITE_PATH)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for entry in DECO_LAYOUT_TITLE:
		_spawn_deco(tex, entry, logo_rect, rng)
	for entry in DECO_LAYOUT_BUTTON:
		_spawn_deco(tex, entry, start_button, rng)

func _spawn_deco(tex: Texture2D, entry: Array, parent: Control, rng: RandomNumberGenerator) -> void:
	var idx: int = entry[0]
	var center: Vector2 = entry[1]
	var rot_deg: float = entry[2]

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var col := idx % 3
	var row := idx / 3
	atlas.region = Rect2(col * DECO_CELL_SIZE, row * DECO_CELL_SIZE, DECO_CELL_SIZE, DECO_CELL_SIZE)

	var rect := TextureRect.new()
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(DECO_DISPLAY_SIZE, DECO_DISPLAY_SIZE)
	rect.size = Vector2(DECO_DISPLAY_SIZE, DECO_DISPLAY_SIZE)
	rect.pivot_offset = Vector2(DECO_DISPLAY_SIZE * 0.5, DECO_DISPLAY_SIZE * 0.5)
	rect.rotation = deg_to_rad(rot_deg)
	rect.position = center - Vector2(DECO_DISPLAY_SIZE * 0.5, DECO_DISPLAY_SIZE * 0.5)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

	_decorations.append({
		"rect": rect,
		"base_pos": rect.position,
		"base_rot": rect.rotation,
		"amp_x": rng.randf_range(2.0, 3.5),
		"amp_y": rng.randf_range(2.0, 3.5),
		"amp_rot": rng.randf_range(0.015, 0.04),
		"period": rng.randf_range(2.8, 4.2),
		"period_rot": rng.randf_range(3.4, 5.0),
		"phase": rng.randf() * TAU,
		"phase_rot": rng.randf() * TAU,
	})
