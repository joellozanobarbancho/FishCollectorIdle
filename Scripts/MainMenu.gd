extends Control

const LOGIN_SCENE_PATH := "res://Scenes/Login.tscn"
const REGISTER_SCENE_PATH := "res://Scenes/Register.tscn"


func _on_login_button_pressed() -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE_PATH)


func _on_register_button_pressed() -> void:
	get_tree().change_scene_to_file(REGISTER_SCENE_PATH)
