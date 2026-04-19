extends Control

class_name CooldownOrb

var progress: float = 1.0:
	set(value):
		progress = clamp(value, 0.0, 1.0)
		queue_redraw()


func set_progress(value: float) -> void:
	progress = value


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var radius: float = (min(size.x, size.y) * 0.5) - 1.5
	if radius <= 0.0:
		return

	var center := size * 0.5
	var background_color := Color(1.0, 1.0, 1.0, 0.20)
	var fill_color := Color(1.0, 1.0, 1.0, 0.92)
	var border_color := Color(1.0, 1.0, 1.0, 1.0)

	draw_circle(center, radius, background_color)

	if progress > 0.0:
		_draw_sector(center, radius - 1.0, -PI * 0.5, (-PI * 0.5) + (TAU * progress), fill_color)

	draw_arc(center, radius, 0.0, TAU, 48, border_color, 1.5, true)


func _draw_sector(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	if end_angle <= start_angle or radius <= 0.0:
		return

	var points := PackedVector2Array()
	points.append(center)

	var segments: int = max(8, int(64.0 * ((end_angle - start_angle) / TAU)))
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle: float = start_angle + ((end_angle - start_angle) * t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	draw_colored_polygon(points, color)
