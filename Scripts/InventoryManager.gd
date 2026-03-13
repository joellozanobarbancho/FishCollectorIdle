extends Node

func get_inventory() -> Array:
	return File.data["player"]["inventory"]

func add_fish(fish_id: int, size: int, value: int, location_id: String = "") -> void:
	if location_id == "":
		location_id = String(File.data["player"].get("current_location", "river_bank"))

	var entry = {
		"fish_id": fish_id,
		"size": size,
		"value": value,
		"location_id": location_id,
		"caught_at": Time.get_datetime_string_from_system()
	}

	File.data["player"]["inventory"].append(entry)

	var fish_data: Dictionary = DataManager.fish_db.get(fish_id, {})
	var xp_on_catch := 0
	if typeof(fish_data) == TYPE_DICTIONARY and fish_data.has("xp_on_catch"):
		xp_on_catch = int(fish_data["xp_on_catch"])

	var location_xp_multiplier := DataManager.get_location_xp_multiplier(location_id)
	xp_on_catch = int(round(float(xp_on_catch) * location_xp_multiplier))

	if xp_on_catch > 0:
		LevelManager.add_xp(xp_on_catch)

	File.save_game()
	FirebaseManager.upload_save()

func remove_fish(index: int) -> void:
	var inv = File.data["player"]["inventory"]
	if index >= 0 and index < inv.size():
		inv.remove_at(index)
		File.save_game()
		FirebaseManager.upload_save()

func clear_inventory() -> void:
	File.data["player"]["inventory"].clear()
	File.save_game()
	FirebaseManager.upload_save()

func get_total_value() -> int:
	var total := 0
	for item in File.data["player"]["inventory"]:
		total += item["value"]
	return total
