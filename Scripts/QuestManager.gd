extends Node

func _is_numeric(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func claim_quest(quest_id: int) -> bool:
	var quest = DataManager.quests_db.get(quest_id)
	if quest == null:
		return false

	var achievements: Array = Data.save_data["player"].get("achievements", [])
	if achievements.any(func(a): return a.get("quest_id") == quest_id):
		return false

	var reward: Dictionary = quest.get("reward", {})
	if typeof(reward) != TYPE_DICTIONARY:
		reward = {}

	if reward.has("coins") and _is_numeric(reward["coins"]):
		Data.save_data["player"]["coins"] += reward["coins"]

	if reward.has("stats") and typeof(reward["stats"]) == TYPE_DICTIONARY:
		var base_stats: Dictionary = Data.save_data["player"]["base_stats"]
		for stat_key in reward["stats"].keys():
			var stat_value = reward["stats"][stat_key]
			if not _is_numeric(stat_value):
				continue
			if not base_stats.has(stat_key):
				base_stats[stat_key] = 0
			base_stats[stat_key] += stat_value
		UpgradeManager.apply_items()

	if reward.has("flags") and typeof(reward["flags"]) == TYPE_DICTIONARY:
		for flag_key in reward["flags"].keys():
			var flag_value = reward["flags"][flag_key]
			if typeof(flag_value) == TYPE_BOOL:
				Data.save_data["player"][flag_key] = flag_value

	achievements.append({
		"quest_id": quest_id,
		"name": quest.get("name", ""),
		"description": quest.get("description", ""),
		"unlocked_at": Time.get_datetime_string_from_system()
	})
	Data.save_data["player"]["achievements"] = achievements

	File.save_game()

	return true
