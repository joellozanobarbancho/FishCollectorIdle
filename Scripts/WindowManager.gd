extends Node

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if (event.alt_pressed and event.keycode == KEY_ENTER) or event.keycode == KEY_F11:
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
