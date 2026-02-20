extends Node

var fish_db: Dictionary = {}
var upgrades_db: Dictionary = {}
var quests_db: Dictionary = {}
var achievements_db: Dictionary = {}

func _ready():
	load_all_databases()

func load_all_databases():
	fish_db = load_database("res://database/fish")
	upgrades_db = load_database("res://database/upgrades")
	quests_db = load_database("res://database/quests")

func load_database(path: String) -> Dictionary:
	var db := {}
	var dir := DirAccess.open(path)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open(path + "/" + file_name, FileAccess.READ)
				var parsed = JSON.parse_string(file.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY:
					db[parsed["id"]] = parsed
			file_name = dir.get_next()

	return db
