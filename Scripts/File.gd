extends Node

const SAVE_PATH := "user://save.json"

var access: FileAccess

func new_game() -> void:
	Data.save_data = {
		"player": {
			"id": 1,
			"name": "default_player",
			"email": "",
			"createdAt": Time.get_datetime_string_from_system(),
			"current_location": "river_bank",
			"inventory": [],
			"coins": 0,
			"level": 1,
			"xp": 0,
			"social_features_enabled": false,

			"base_stats": {
				"fishing_stamina": 100.0,
				"fishing_stamina_regen": 0.1,
				"fishing_speed": 15.0,
				"chest_chance": 1.0,
				"fish_chance": 1.0, 
				"rare_fish_chance": 1.0,
				"xp_multiplier": 1.0,
			},

			"current_stats": {},

			"items_owned": {},
			"achievements": []
		},

		"world_state": {}
	}

	save_game()

func save_game() -> void:
	access = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	access.store_string(JSON.stringify(Data.save_data, "\t"))
	access.close()

func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		access = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text := access.get_as_text()
		access.close()

		var parsed: Variant = JSON.parse_string(text)

		if typeof(parsed) == TYPE_DICTIONARY:
			Data.save_data = parsed
			if not Data.save_data.has("player"):
				Data.save_data["player"] = {}
			if not Data.save_data["player"].has("current_location"):
				Data.save_data["player"]["current_location"] = "river_bank"
			if not Data.save_data["player"].has("xp"):
				Data.save_data["player"]["xp"] = 0
			if not Data.save_data["player"].has("level"):
				Data.save_data["player"]["level"] = 1
			if not Data.save_data["player"].has("social_features_enabled"):
				Data.save_data["player"]["social_features_enabled"] = false
			if not Data.save_data["player"].has("current_stats"):
				Data.save_data["player"]["current_stats"] = {}
			if not Data.save_data["player"].has("items_owned"):
				Data.save_data["player"]["items_owned"] = {}
			if not Data.save_data["player"].has("achievements"):
				Data.save_data["player"]["achievements"] = []
			#falta aplicar mejoras, logros, etc
		else:
			push_error("Error al parsear el JSON")
	else:
		new_game()
