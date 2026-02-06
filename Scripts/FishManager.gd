extends Node

var fish_db: Dictionary = {}

func _ready() -> void:
	load_all_databases()

func load_all_databases() -> void:
	fish_db = load_fish_database()

func load_fish_database() -> Dictionary:
	var fish_db := {}
	var dir := DirAccess.open("res://database/fish")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var path = "res://Database/fish/" + file_name
				var file = FileAccess.open(path, FileAccess.READ)
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY:
					fish_db[parsed["id"]] = parsed
			file_name = dir.get_next()

	return fish_db
