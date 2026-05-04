extends Control

# Constantes del minijuego
const CIRCLE_RADIUS: float = 80.0
const INDICATOR_SPEED: float = 0.6  # vueltas por segundo
const SUCCESS_ZONE_SIZE: float = 45.0  # grados (reducido a la mitad)
const TIMEOUT_SECONDS: float = 5.0

# Señales
signal skill_check_completed(success: bool, fish_id: int, fish_data: Dictionary)

# Variables
var fish_id: int = -1
var fish_data: Dictionary = {}
var indicator_angle: float = 0.0
var time_elapsed: float = 0.0
var has_responded: bool = false
var center_position: Vector2 = Vector2.ZERO
var success_zone_angle: float = 0.0  # Ángulo aleatorio de la zona de éxito

@onready var timer_label: Label = $PopupPanel/VBoxContainer/TimerLabel
@onready var instruction_label: Label = $PopupPanel/VBoxContainer/InstructionLabel
@onready var canvas: Control = $PopupPanel/VBoxContainer/SkillCheckCanvas
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var fail_sound: AudioStreamPlayer = $FailSound


func _ready() -> void:
	if canvas:
		center_position = canvas.size / 2.0
		# Generar ángulo aleatorio para la zona de éxito
		success_zone_angle = randf_range(0.0, 360.0)
		# Pasar el ángulo al canvas
		if canvas.has_method("set_success_zone_angle"):
			canvas.set_success_zone_angle(success_zone_angle)
		canvas.queue_redraw()
		print("SkillCheck: success_zone_angle = ", success_zone_angle)
	else:
		push_error("SkillCheck: Canvas not found")
	
	get_tree().root.gui_embed_subwindows = false


func _process(delta: float) -> void:
	if has_responded:
		return
	
	time_elapsed += delta
	
	# Calcular ángulo del indicador (rotación continua)
	indicator_angle = fmod(time_elapsed * INDICATOR_SPEED * 360.0, 360.0)
	
	# Actualizar timer
	var remaining_time: float = max(TIMEOUT_SECONDS - time_elapsed, 0.0)
	if timer_label:
		timer_label.text = "%.1f" % remaining_time
	
	# Timeout
	if time_elapsed >= TIMEOUT_SECONDS:
		_on_skill_check_failed()
	
	# Actualizar el canvas con el nuevo ángulo
	if canvas and canvas.has_method("update_angle"):
		canvas.update_angle(indicator_angle)


func _input(event: InputEvent) -> void:
	if has_responded or not (event is InputEventMouseButton):
		return
	
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	
	# Verificar el ángulo actual del indicador en el momento del click
	_check_click_position()


func _check_click_position() -> void:
	if not canvas:
		_on_skill_check_failed()
		return
	
	# Calcular la diferencia angular entre el indicador y la zona de éxito
	var angle_difference: float = abs(indicator_angle - success_zone_angle)
	
	# Ajustar si la diferencia es mayor a 180 (tomar el camino más corto)
	if angle_difference > 180.0:
		angle_difference = 360.0 - angle_difference

	print("Indicator angle: ", indicator_angle, " | Success zone: ", success_zone_angle, " | Difference: ", angle_difference, " | Tolerance: ", SUCCESS_ZONE_SIZE / 2.0)
	
	# Verificar si está dentro de la zona de éxito
	if angle_difference <= SUCCESS_ZONE_SIZE / 2.0:
		_on_skill_check_succeeded()
	else:
		_on_skill_check_failed()


func _on_skill_check_succeeded() -> void:
	has_responded = true
	if instruction_label:
		instruction_label.text = "Success!"
		instruction_label.add_theme_color_override("font_color", Color.GREEN)
	if success_sound:
		success_sound.play()
	await get_tree().create_timer(0.5).timeout
	skill_check_completed.emit(true, fish_id, fish_data)
	queue_free()


func _on_skill_check_failed() -> void:
	has_responded = true
	if instruction_label:
		instruction_label.text = "Failed!"
		instruction_label.add_theme_color_override("font_color", Color.RED)
	if fail_sound:
		fail_sound.play()
	await get_tree().create_timer(0.5).timeout
	skill_check_completed.emit(false, fish_id, fish_data)
	queue_free()


func set_fish_data(new_fish_id: int, new_fish_data: Dictionary) -> void:
	fish_id = new_fish_id
	fish_data = new_fish_data.duplicate()


func show_skill_check(parent: Node) -> void:
	parent.add_child(self)
