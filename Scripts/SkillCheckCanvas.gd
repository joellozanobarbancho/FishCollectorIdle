extends Control

# Referencias
var skill_check: Control
var indicator_angle: float = 0.0
var time_elapsed: float = 0.0

# Constantes (deben ser iguales a las del SkillCheck)
const CIRCLE_RADIUS: float = 80.0
const SUCCESS_ZONE_SIZE: float = 45.0
const INDICATOR_SPEED: float = 0.6

# Variable para el ángulo de la zona de éxito (se establece dinámicamente)
var success_zone_angle: float = 270.0


func _ready() -> void:
	# Obtener referencia al nodo padre SkillCheck
	skill_check = get_parent().get_parent()
	queue_redraw()


func _draw() -> void:
	var center_position: Vector2 = get_rect().size / 2.0
	
	# Dibujar círculo de fondo
	draw_circle(center_position, CIRCLE_RADIUS, Color(0.1, 0.1, 0.15, 0.8))
	
	# Dibujar borde del círculo
	draw_arc(center_position, CIRCLE_RADIUS, 0, TAU, 64, Color.WHITE, 2.0)
	
	# Dibujar zona de éxito (arco) - ESTÁTICA
	var success_zone_start: float = deg_to_rad(success_zone_angle - SUCCESS_ZONE_SIZE / 2.0)
	var success_zone_end: float = deg_to_rad(success_zone_angle + SUCCESS_ZONE_SIZE / 2.0)
	var success_zone_points: PackedVector2Array = PackedVector2Array()
	for point_index in range(33):
		var t: float = float(point_index) / 32.0
		var angle: float = lerp(success_zone_start, success_zone_end, t)
		success_zone_points.append(center_position + Vector2(cos(angle), sin(angle)) * CIRCLE_RADIUS)
	draw_polyline(success_zone_points, Color(0.0, 1.0, 0.0, 0.9), 8.0, true)
	
	# Dibujar indicador (línea)
	var indicator_angle_rad: float = deg_to_rad(indicator_angle)
	var indicator_end: Vector2 = center_position + Vector2(
		cos(indicator_angle_rad) * CIRCLE_RADIUS,
		sin(indicator_angle_rad) * CIRCLE_RADIUS
	)
	draw_line(center_position, indicator_end, Color.YELLOW, 4.0)
	
	# Dibujar círculo en la punta del indicador
	draw_circle(indicator_end, 8.0, Color.YELLOW)


func update_angle(angle: float) -> void:
	indicator_angle = angle
	queue_redraw()


func get_center_position() -> Vector2:
	return size / 2.0


func get_canvas_radius() -> float:
	return CIRCLE_RADIUS


func set_success_zone_angle(angle: float) -> void:
	success_zone_angle = angle
	queue_redraw()
