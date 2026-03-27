extends Node

var fish_db: Dictionary = {}
var items_db: Dictionary = {}
var quests_db: Dictionary = {}
var levels_db: Dictionary = {}
var locations_db: Dictionary = {}

func _ready():
	load_all_databases()

func load_all_databases():
	fish_db = load_database("res://Database/fish")
	items_db = load_items_file("res://Database/store/store.json")
	quests_db = load_database("res://Database/quests")
	levels_db = load_database("res://Database/levels")
	locations_db = load_database("res://Database/locations")


func load_items_file(path: String) -> Dictionary:
	var db := {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: could not open " + path)
		return db
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("items"):
		push_error("DataManager: store.json must have an \"items\" array")
		return db
	for entry in parsed["items"]:
		if typeof(entry) == TYPE_DICTIONARY:
			var normalized = _normalize_item_entry(entry)
			if not normalized.is_empty():
				db[normalized["id"]] = normalized
	return db


func _normalize_item_entry(entry: Dictionary) -> Dictionary:
	if not entry.has("id") or not entry.has("max_level") or not entry.has("levels"):
		return {}
	if typeof(entry["levels"]) != TYPE_ARRAY or entry["levels"].is_empty():
		return {}
	return entry


func _normalize_location_entry(entry: Dictionary) -> Dictionary:
	if not entry.has("id") or not entry.has("rarity_multiplier") or not entry.has("xp_multiplier"):
		return {}
	if not _is_numeric(entry["rarity_multiplier"]) or not _is_numeric(entry["xp_multiplier"]):
		return {}

	var normalized = entry.duplicate(true)
	if not normalized.has("habitat"):
		normalized["habitat"] = "Any"
	return normalized


func _is_numeric(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _normalize_quest_reward(reward: Variant) -> Dictionary:
	if _is_numeric(reward):
		return {"coins": reward}

	if typeof(reward) != TYPE_DICTIONARY:
		return {}

	var normalized_reward := {}
	if reward.has("coins") and _is_numeric(reward["coins"]):
		normalized_reward["coins"] = reward["coins"]

	if reward.has("stats") and typeof(reward["stats"]) == TYPE_DICTIONARY:
		var normalized_stats := {}
		for stat_key in reward["stats"].keys():
			var stat_value = reward["stats"][stat_key]
			if _is_numeric(stat_value):
				normalized_stats[stat_key] = stat_value
		if not normalized_stats.is_empty():
			normalized_reward["stats"] = normalized_stats

	if reward.has("flags") and typeof(reward["flags"]) == TYPE_DICTIONARY:
		var normalized_flags := {}
		for flag_key in reward["flags"].keys():
			var flag_value = reward["flags"][flag_key]
			if typeof(flag_value) == TYPE_BOOL:
				normalized_flags[flag_key] = flag_value
		if not normalized_flags.is_empty():
			normalized_reward["flags"] = normalized_flags

	return normalized_reward


func _normalize_quest_entry(entry: Dictionary) -> Dictionary:
	if not entry.has("id"):
		return {}

	var reward = _normalize_quest_reward(entry.get("reward", {}))
	var normalized = entry.duplicate(true)
	normalized["reward"] = reward
	return normalized


func _add_entry_to_db(db: Dictionary, entry: Dictionary, is_items_db: bool, is_quests_db: bool, is_locations_db: bool) -> void:
	if is_items_db:
		var normalized = _normalize_item_entry(entry)
		if not normalized.is_empty() and normalized.has("id"):
			db[normalized["id"]] = normalized
	elif is_quests_db:
		var normalized = _normalize_quest_entry(entry)
		if not normalized.is_empty() and normalized.has("id"):
			db[normalized["id"]] = normalized
	elif is_locations_db:
		var normalized = _normalize_location_entry(entry)
		if not normalized.is_empty() and normalized.has("id"):
			db[normalized["id"]] = normalized
	elif entry.has("id"):
		db[entry["id"]] = entry

func load_database(path: String) -> Dictionary:
	var db := {}
	var dir := DirAccess.open(path)
	var is_items_db := path.ends_with("/upgrades")
	var is_quests_db := path.ends_with("/quests")
	var is_locations_db := path.ends_with("/locations")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open(path + "/" + file_name, FileAccess.READ)
				if file == null:
					file_name = dir.get_next()
					continue
				var parsed = JSON.parse_string(file.get_as_text())

				if typeof(parsed) == TYPE_DICTIONARY:
					if parsed.has("id"):
						_add_entry_to_db(db, parsed, is_items_db, is_quests_db, is_locations_db)
					elif parsed.has("upgrades") and typeof(parsed["upgrades"]) == TYPE_ARRAY:
						for entry in parsed["upgrades"]:
							if typeof(entry) == TYPE_DICTIONARY:
								_add_entry_to_db(db, entry, is_items_db, is_quests_db, is_locations_db)
					elif parsed.has("quests") and typeof(parsed["quests"]) == TYPE_ARRAY:
						for entry in parsed["quests"]:
							if typeof(entry) == TYPE_DICTIONARY:
								_add_entry_to_db(db, entry, is_items_db, is_quests_db, is_locations_db)
				elif typeof(parsed) == TYPE_ARRAY:
					for entry in parsed:
						if typeof(entry) == TYPE_DICTIONARY:
							_add_entry_to_db(db, entry, is_items_db, is_quests_db, is_locations_db)
			file_name = dir.get_next()

	return db


func get_location(location_id: String) -> Dictionary:
	if locations_db.has(location_id):
		return locations_db[location_id]
	if locations_db.has("river_bank"):
		return locations_db["river_bank"]
	if locations_db.is_empty():
		return {}
	return locations_db[locations_db.keys()[0]]


func get_location_rarity_multiplier(location_id: String) -> float:
	var location = get_location(location_id)
	if location.is_empty():
		return 1.0
	return max(float(location.get("rarity_multiplier", 1.0)), 0.1)


func get_location_xp_multiplier(location_id: String) -> float:
	var location = get_location(location_id)
	if location.is_empty():
		return 1.0
	return max(float(location.get("xp_multiplier", 1.0)), 0.1)


func get_fish_weight_for_location(fish_data: Dictionary, location_id: String) -> float:
	if fish_data.is_empty():
		return 0.0

	var location = get_location(location_id)
	if not location.is_empty() and location.has("habitat"):
		var fish_habitat := String(fish_data.get("habitat", "Any"))
		var zone_habitat := String(location.get("habitat", "Any"))
		if zone_habitat != "Any" and fish_habitat != zone_habitat:
			return 0.0

	var rarity_value: float = max(float(fish_data.get("rarity", 1.0)), 1.0)
	var rarity_multiplier := get_location_rarity_multiplier(location_id)
	return 1.0 / pow(rarity_value, rarity_multiplier)


func get_random_fish_id_for_location(location_id: String) -> int:
	if fish_db.is_empty():
		return -1

	var candidates: Array = []
	var total_weight := 0.0

	for fish_id in fish_db.keys():
		var fish_data: Dictionary = fish_db[fish_id]
		var weight := get_fish_weight_for_location(fish_data, location_id)
		if weight > 0.0:
			candidates.append({"id": fish_id, "weight": weight})
			total_weight += weight

	if candidates.is_empty() or total_weight <= 0.0:
		return -1

	var roll := randf() * total_weight
	for candidate in candidates:
		roll -= float(candidate["weight"])
		if roll <= 0.0:
			return int(candidate["id"])

	return int(candidates[candidates.size() - 1]["id"])
