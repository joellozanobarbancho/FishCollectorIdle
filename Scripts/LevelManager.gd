extends Node

signal level_up(new_level: int)
signal xp_changed(level: int, current_xp: int, next_level_xp: int)


func add_xp(base_amount: int) -> void:
	if base_amount <= 0:
		return

	var multiplier: float = File.data["player"]["current_stats"].get("xp_multiplier", 1.0)
	var gained := int(base_amount * multiplier)
	File.data["player"]["xp"] += gained
	_check_level_up()
	_emit_xp_changed()


func _check_level_up() -> void:
	var current_level: int = File.data["player"]["level"]
	var current_xp: int = File.data["player"]["xp"]
	var next_level := current_level + 1

	var next_level_data = DataManager.levels_db.get(next_level)
	if next_level_data == null:
		return

	if current_xp >= next_level_data["xp_required"]:
		File.data["player"]["level"] = next_level

		emit_signal("level_up", next_level)

		File.save_game()
		FirebaseManager.upload_save()

		_check_level_up()


func _emit_xp_changed() -> void:
	var progress = get_level_progress()
	emit_signal("xp_changed", progress["level"], progress["xp"], progress["next_level_xp"])


func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var level_data = DataManager.levels_db.get(level)
	if level_data == null:
		return -1
	return level_data["xp_required"]


func get_max_level() -> int:
	return DataManager.levels_db.keys().max() if not DataManager.levels_db.is_empty() else 1


func get_level_progress() -> Dictionary:
	var level: int = File.data["player"].get("level", 1)
	var xp: int = File.data["player"].get("xp", 0)
	var current_level_xp := get_xp_for_level(level)
	var next_level_xp := get_xp_for_level(level + 1)

	if next_level_xp == -1:
		return {
			"level": level,
			"xp": xp,
			"current_level_xp": current_level_xp,
			"next_level_xp": current_level_xp,
			"progress": 1.0
		}

	var span := max(next_level_xp - current_level_xp, 1)
	var progress_value := clamp(float(xp - current_level_xp) / float(span), 0.0, 1.0)

	return {
		"level": level,
		"xp": xp,
		"current_level_xp": current_level_xp,
		"next_level_xp": next_level_xp,
		"progress": progress_value
	}
