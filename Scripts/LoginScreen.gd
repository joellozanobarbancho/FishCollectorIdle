extends Control

const FISHING_SCENE_PATH := "res://Scenes/FishingScreen.tscn"
const REGISTER_SCENE_PATH := "res://Scenes/Register.tscn"
const HOME_SCENE_PATH := "res://Scenes/MainMenu.tscn"
const POPUP_DISPLAY_TIME := 2.5

@onready var email_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Email
@onready var password_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Password
@onready var login_button: Button = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/LoginButton
@onready var error_popup_container: PanelContainer = $ErrorPopupLayer/ErrorPopupContainer
@onready var error_popup_label: Label = $ErrorPopupLayer/ErrorPopupContainer/ErrorPopupMargin/ErrorPopupLabel

var _popup_revision: int = 0


func _ready() -> void:
	password_input.secret = true

func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".")


func _show_error_popup(message: String, duration: float = POPUP_DISPLAY_TIME) -> void:
	_popup_revision += 1
	var current_revision: int = _popup_revision

	error_popup_label.text = message
	error_popup_container.visible = true

	await get_tree().create_timer(duration).timeout
	if current_revision == _popup_revision:
		error_popup_container.visible = false


func _on_login_button_pressed() -> void:
	var email := email_input.text.strip_edges()
	var password := password_input.text

	if email.is_empty() or password.is_empty():
		_show_error_popup("Email and password are required")
		return

	if not _is_valid_email(email):
		_show_error_popup("Please enter a valid email")
		return

	login_button.disabled = true

	var login_ok: bool = await FirebaseManager.login(email, password)
	if login_ok:
		await _show_error_popup("Login successful!", 1.0)
		get_tree().change_scene_to_file(FISHING_SCENE_PATH)
		return

	var auth_error: String = FirebaseManager.last_auth_error
	if auth_error == "EMAIL_NOT_FOUND":
		_show_error_popup("No account found, opening register...")
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file(REGISTER_SCENE_PATH)
		return
	
	if auth_error == "Account data not found. Try to Register.":
		_show_error_popup("Account was deleted. Please register again...")
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file(REGISTER_SCENE_PATH)
		return

	_show_error_popup("Login failed: %s" % auth_error)
	login_button.disabled = false


func _on_forgot_password_button_pressed() -> void:
	var email := email_input.text.strip_edges()

	if email.is_empty():
		_show_error_popup("Enter your email first")
		return

	if not _is_valid_email(email):
		_show_error_popup("Please enter a valid email")
		return

	_show_error_popup("Sending password reset email...")
	var reset_ok: bool = await FirebaseManager.send_password_reset_email(email)
	if reset_ok:
		_show_error_popup("Reset email sent. Check your inbox")
	else:
		_show_error_popup("Reset failed: %s" % FirebaseManager.last_auth_error)


func _on_back_to_home_button_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE_PATH)
