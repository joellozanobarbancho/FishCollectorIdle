extends Node

# Purchase the next level of an item. Returns false if maxed, can't afford, or item not found.
func buy_item(item_id: String) -> bool:
	var item = DataManager.items_db.get(item_id)
	if item == null:
		return false

	var current_level: int = Data.save_data["player"]["items_owned"].get(item_id, 0)
	if current_level >= item["max_level"]:
		return false  # already at max level

	# levels array is 0-indexed; next level to buy is at index current_level
	var next_level_data: Dictionary = item["levels"][current_level]
	var cost: int = next_level_data["cost"]

	if Data.save_data["player"]["coins"] < cost:
		return false

	Data.save_data["player"]["coins"] -= cost
	Data.save_data["player"]["items_owned"][item_id] = current_level + 1

	apply_items()

	File.save_game()
	FirebaseManager.upload_save()

	return true


# Recalculates current_stats from base_stats + all purchased item levels.
func apply_items() -> void:
	var base_stats = Data.save_data["player"]["base_stats"]
	var current_stats = Data.save_data["player"]["current_stats"]

	current_stats.clear()
	for key in base_stats.keys():
		current_stats[key] = base_stats[key]

	for item_id in Data.save_data["player"]["items_owned"].keys():
		var item = DataManager.items_db.get(item_id)
		if item == null:
			continue

		var owned_level: int = Data.save_data["player"]["items_owned"][item_id]
		for i in range(owned_level):
			var level_data: Dictionary = item["levels"][i]
			for effect_key in level_data["effect"].keys():
				if not current_stats.has(effect_key):
					current_stats[effect_key] = 0
				current_stats[effect_key] += level_data["effect"][effect_key]


# Returns the cost of the next level, or -1 if maxed / not found.
func get_next_level_cost(item_id: String) -> int:
	var item = DataManager.items_db.get(item_id)
	if item == null:
		return -1
	var current_level: int = Data.save_data["player"]["items_owned"].get(item_id, 0)
	if current_level >= item["max_level"]:
		return -1
	return item["levels"][current_level]["cost"]


# Returns the current owned level for an item (0 = not purchased).
func get_item_level(item_id: String) -> int:
	return Data.save_data["player"]["items_owned"].get(item_id, 0)
