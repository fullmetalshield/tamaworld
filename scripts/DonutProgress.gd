class_name DonutProgress
extends Control

# Donut-shaped progress indicator. `progress` is 0..1; setting it triggers a
# redraw. The arc starts at 12 o'clock and fills clockwise on top of a faint
# background ring.

@export var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var thickness: float = 20.0:
	set(value):
		thickness = max(1.0, value)
		queue_redraw()
@export var bg_color: Color = Color(0.95, 0.86, 0.88, 1):
	set(value):
		bg_color = value
		queue_redraw()
@export var fill_color: Color = Color(0.95, 0.45, 0.55, 1):
	set(value):
		fill_color = value
		queue_redraw()
@export var fill_center: bool = false:
	set(value):
		fill_center = value
		queue_redraw()
@export var center_color: Color = Color(1, 1, 1, 0.85):
	set(value):
		center_color = value
		queue_redraw()

const ARC_SEGMENTS := 48

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * 0.5 - thickness * 0.5
	if radius <= 0.0:
		return
	if fill_center:
		draw_circle(center, max(0.0, radius - thickness * 0.5), center_color)
	draw_arc(center, radius, 0.0, TAU, ARC_SEGMENTS, bg_color, thickness, true)
	if progress > 0.0:
		var start_angle: float = -PI * 0.5
		var end_angle: float = start_angle + TAU * progress
		draw_arc(center, radius, start_angle, end_angle, ARC_SEGMENTS, fill_color, thickness, true)
