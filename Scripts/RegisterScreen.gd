extends Control

const FISHING_SCENE_PATH := "res://Scenes/FishingScreen.tscn"
const LOGIN_SCENE_PATH := "res://Scenes/Login.tscn"
const HOME_SCENE_PATH := "res://Scenes/MainMenu.tscn"
const POPUP_DISPLAY_TIME := 2.5

@onready var email_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Email
@onready var username_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Username
@onready var password_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Password
@onready var confirm_password_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/ConfirmPassword
@onready var register_button: Button = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/RegisterButton
@onready var error_popup_container: PanelContainer = $ErrorPopupLayer/ErrorPopupContainer
@onready var error_popup_label: Label = $ErrorPopupLayer/ErrorPopupContainer/ErrorPopupMargin/ErrorPopupLabel

var _popup_revision: int = 0
var _popup_waiting_for_click: bool = false

signal popup_clicked


func _ready() -> void:
	password_input.secret = true
	confirm_password_input.secret = true


func _input(event: InputEvent) -> void:
	if not _popup_waiting_for_click or not error_popup_container.visible:
		return

	var left_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if left_click or touch:
		_popup_waiting_for_click = false
		error_popup_container.visible = false
		popup_clicked.emit()


func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".")


func _show_error_popup(message: String, duration: float = POPUP_DISPLAY_TIME, wait_for_click: bool = false) -> void:
	_popup_revision += 1
	var current_revision: int = _popup_revision

	error_popup_label.text = message
	error_popup_container.visible = true
	_popup_waiting_for_click = wait_for_click

	if wait_for_click:
		await popup_clicked
		if current_revision == _popup_revision:
			error_popup_container.visible = false
		return

	await get_tree().create_timer(duration).timeout
	if current_revision == _popup_revision:
		error_popup_container.visible = false


func _on_register_button_pressed() -> void:
	var email := email_input.text.strip_edges()
	var username := username_input.text.strip_edges()
	var password := password_input.text
	var confirm_password := confirm_password_input.text

	if email.is_empty() or username.is_empty() or password.is_empty() or confirm_password.is_empty():
		await _show_error_popup("All fields are required", 0.0, true)
		return

	if not _is_valid_email(email):
		await _show_error_popup("Please enter a valid email", 0.0, true)
		return

	if password != confirm_password:
		await _show_error_popup("Passwords do not match", 0.0, true)
		return

	register_button.disabled = true
	_show_error_popup("Creating account...")

	if Data.save_data.is_empty():
		File.new_game()
	Data.save_data["player"]["name"] = username
	File.save_game()

	var register_ok: bool = await FirebaseManager.register(email, password)
	if register_ok:
		await _show_error_popup("Account created successfully!", 1.0)
		get_tree().change_scene_to_file(FISHING_SCENE_PATH)
		return

	var auth_error: String = FirebaseManager.last_auth_error
	if auth_error == "EMAIL_EXISTS":
		await _show_error_popup("Account already exists, opening login...", 0.0, true)
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
		return

	await _show_error_popup("Register failed: %s" % auth_error, 0.0, true)
	register_button.disabled = false


func _on_back_to_home_button_pressed() -> void:
	if ResourceLoader.exists(HOME_SCENE_PATH):
		get_tree().change_scene_to_file(HOME_SCENE_PATH)
		return
	await _show_error_popup("Home screen not created yet", 0.0, true)
