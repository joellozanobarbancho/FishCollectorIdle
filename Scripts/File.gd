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
			if not data.has("player"):
				data["player"] = {}
			if not data["player"].has("current_location"):
				data["player"]["current_location"] = "river_bank"
			if not data["player"].has("xp"):
				data["player"]["xp"] = 0
			if not data["player"].has("level"):
				data["player"]["level"] = 1
			if not data["player"].has("social_features_enabled"):
				data["player"]["social_features_enabled"] = false
			if not data["player"].has("current_stats"):
				data["player"]["current_stats"] = {}
			if not data["player"].has("items_owned"):
				data["player"]["items_owned"] = {}
			if not data["player"].has("achievements"):
				data["player"]["achievements"] = []
			#falta aplicar mejoras, logros, etc
		else:
			push_error("Error al parsear el JSON")
	else:
		new_game()
