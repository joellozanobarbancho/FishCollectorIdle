extends Node

func get_inventory() -> Array:
	return File.data["player"]["inventory"]

func add_fish(fish_id: int, size: int, value: int) -> void:
	var entry = {
		"fish_id": fish_id,
		"size": size,
		"value": value,
		"caught_at": Time.get_datetime_string_from_system()
	}

	File.data["player"]["inventory"].append(entry)
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
