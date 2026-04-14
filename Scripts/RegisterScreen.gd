extends Control

const FISHING_SCENE_PATH := "res://Scenes/FishingScreen.tscn"
const LOGIN_SCENE_PATH := "res://Scenes/Login.tscn"
const HOME_SCENE_PATH := "res://Scenes/MainMenu.tscn"

@onready var email_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Email
@onready var username_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Username
@onready var password_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/Password
@onready var confirm_password_input: LineEdit = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/ConfirmPassword
@onready var register_button: Button = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/RegisterButton
@onready var status_label: Label = $CenterContainer/AuthCard/MarginContainer/VBoxContainer/StatusLabel
@onready var popup_overlay: ColorRect = $PopupOverlay
@onready var catch_popup: PanelContainer = $CatchPopup


func _ready() -> void:
	password_input.secret = true
	confirm_password_input.secret = true
	status_label.text = "Create your account"
	popup_overlay.visible = false
	catch_popup.visible = false


func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".")


func _on_register_button_pressed() -> void:
	var email := email_input.text.strip_edges()
	var username := username_input.text.strip_edges()
	var password := password_input.text
	var confirm_password := confirm_password_input.text

	if email.is_empty() or username.is_empty() or password.is_empty() or confirm_password.is_empty():
		status_label.text = "All fields are required"
		return

	if not _is_valid_email(email):
		status_label.text = "Please enter a valid email"
		return

	if password != confirm_password:
		status_label.text = "Passwords do not match"
		return

	register_button.disabled = true
	status_label.text = "Creating account..."

	if Data.save_data.is_empty():
		File.new_game()
	Data.save_data["player"]["name"] = username
	Data.save_data["player"]["email"] = email
	File.save_game()

	var register_ok: bool = await FirebaseManager.register(email, password)
	if register_ok:
		status_label.text = "Account created"
		popup_overlay.visible = true
		catch_popup.visible = true
		register_button.disabled = true
		await get_tree().create_timer(1.8).timeout
		get_tree().change_scene_to_file(FISHING_SCENE_PATH)
		return

	var auth_error: String = FirebaseManager.last_auth_error
	if auth_error == "EMAIL_EXISTS":
		status_label.text = "Account already exists, opening login..."
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
		return

	status_label.text = "Register failed: %s" % auth_error
	register_button.disabled = false


func _on_back_to_home_button_pressed() -> void:
	if ResourceLoader.exists(HOME_SCENE_PATH):
		get_tree().change_scene_to_file(HOME_SCENE_PATH)
		return
	status_label.text = "Home screen not created yet"
