extends Control

var skill_check: Control
var indicator_angle: float = 0.0
var time_elapsed: float = 0.0

const CIRCLE_RADIUS: float = 80.0
const SUCCESS_ZONE_SIZE: float = 45.0
const INDICATOR_SPEED: float = 0.6

var success_zone_angle: float = 270.0


func _ready() -> void:
	skill_check = get_parent().get_parent()
	queue_redraw()


func _draw() -> void:
	var center_position: Vector2 = get_rect().size / 2.0

	draw_circle(center_position, CIRCLE_RADIUS, Color(0.1, 0.1, 0.15, 0.8))

	draw_arc(center_position, CIRCLE_RADIUS, 0, TAU, 64, Color.WHITE, 2.0)

	var success_zone_start: float = deg_to_rad(success_zone_angle - SUCCESS_ZONE_SIZE / 2.0)
	var success_zone_end: float = deg_to_rad(success_zone_angle + SUCCESS_ZONE_SIZE / 2.0)
	var success_zone_points: PackedVector2Array = PackedVector2Array()
	for point_index in range(33):
		var t: float = float(point_index) / 32.0
		var angle: float = lerp(success_zone_start, success_zone_end, t)
		success_zone_points.append(center_position + Vector2(cos(angle), sin(angle)) * CIRCLE_RADIUS)
	draw_polyline(success_zone_points, Color(0.0, 1.0, 0.0, 0.9), 8.0, true)

	var indicator_angle_rad: float = deg_to_rad(indicator_angle)
	var indicator_end: Vector2 = center_position + Vector2(
		cos(indicator_angle_rad) * CIRCLE_RADIUS,
		sin(indicator_angle_rad) * CIRCLE_RADIUS
	)
	draw_line(center_position, indicator_end, Color.YELLOW, 4.0)

	draw_circle(indicator_end, 8.0, Color.YELLOW)


func update_angle(angle: float) -> void:
	indicator_angle = angle
	queue_redraw()


func set_success_zone_angle(angle: float) -> void:
	success_zone_angle = angle
	queue_redraw()
