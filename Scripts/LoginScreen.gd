extends Control

const FISHING_SCENE_PATH := "res://Scenes/FishingScreen.tscn"
const REGISTER_SCENE_PATH := "res://Scenes/Register.tscn"

@onready var email_input: LineEdit = $NinePatchRect/MarginContainer/VBoxContainer/Email
@onready var password_input: LineEdit = $NinePatchRect/MarginContainer/VBoxContainer/Password
@onready var login_button: Button = $NinePatchRect/MarginContainer/VBoxContainer/LoginButton
@onready var status_label: Label = $NinePatchRect/MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	password_input.secret = true
	status_label.text = "Log into your account"


func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".")


func _on_login_button_pressed() -> void:
	var email := email_input.text.strip_edges()
	var password := password_input.text

	if email.is_empty() or password.is_empty():
		status_label.text = "Email and password are required"
		return

	if not _is_valid_email(email):
		status_label.text = "Please enter a valid email"
		return

	login_button.disabled = true
	status_label.text = "Signing in..."

	var login_ok: bool = await FirebaseManager.login(email, password)
	if login_ok:
		status_label.text = "Login successful"
		get_tree().change_scene_to_file(FISHING_SCENE_PATH)
		return

	var auth_error: String = FirebaseManager.last_auth_error
	if auth_error == "EMAIL_NOT_FOUND":
		status_label.text = "No account found, opening register..."
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file(REGISTER_SCENE_PATH)
		return

	status_label.text = "Login failed: %s" % auth_error
	login_button.disabled = false
