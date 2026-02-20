extends Node

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}
var access: FileAccess

func new_game() -> void:
	data = {
		"player": {
			"id": 1,
			"name": "default_player",
			"email": "",
			"createdAt": Time.get_datetime_string_from_system(),
			"inventory": [],
			"coins": 0,

			"base_stats": {
				"fishing_cooldown": 20.0,
				"fishing_speed": 15.0,
				"chest_chance": 1.0,
				"trade_cooldown": 60.0,
				"can_autosell": false,
				"rare_fish_chance": 0.0,
				"xp_multiplier": 1.0
			},

			"current_stats": {},

			"upgrades_owned": []
		},

		"world_state": {}
	}

	save_game()

func save_game() -> void:
	access = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	access.store_string(JSON.stringify(data, "\t"))
	access.close()

func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		access = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text := access.get_as_text()
		access.close()

		var parsed: Variant = JSON.parse_string(text)

		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
			#falta aplicar mejoras, logros, etc
		else:
			push_error("Error al parsear el JSON")
	else:
		new_game()
