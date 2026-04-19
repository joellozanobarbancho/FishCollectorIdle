extends Control

const BASE_CATCH_CHANCE: float = 0.85
const BASE_STAMINA_COST: float = 15.0
const BASE_REGEN_PER_SECOND: float = 0.1
const MIN_CAST_INTERVAL: float = 0.15

@onready var coins_label: Label = $Panel/MarginContainer/VBoxContainer/CoinsLabel
@onready var stamina_label: Label = $Panel/MarginContainer/VBoxContainer/StaminaLabel
@onready var fish_button: Button = $Panel/MarginContainer/VBoxContainer/FishButton
@onready var result_label: Label = $Panel/MarginContainer/VBoxContainer/ResultLabel
@onready var inventory_dropdown: Control = $InventoryDropdown
@onready var grid_container: GridContainer = $InventoryDropdown/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var cast_cooldown_remaining: float = 0.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var card_fish_ids: Array[int] = [-1, -1, -1, -1]


func _ready() -> void:
	randomize()
	if Data.save_data.is_empty():
		File.load_game()
	_ensure_player_defaults()
	_pull_stamina_from_stats()
	inventory_dropdown.visible = false
	_refresh_ui("Ready to fish.")
	_connect_sell_buttons()


func _process(delta: float) -> void:
	if cast_cooldown_remaining > 0.0:
		cast_cooldown_remaining = max(cast_cooldown_remaining - delta, 0.0)

	var regen_rate: float = max(_get_stat_float("fishing_stamina_regen", BASE_REGEN_PER_SECOND), 0.0)
	stamina = min(stamina + regen_rate * delta, max_stamina)

	var stamina_cost: float = _get_stamina_cost()
	fish_button.disabled = cast_cooldown_remaining > 0.0 or stamina < stamina_cost

	_update_coins_label()
	_update_stamina_label()


func _on_fish_button_pressed() -> void:
	if cast_cooldown_remaining > 0.0:
		result_label.text = "Reel cooldown: %.1fs" % cast_cooldown_remaining
		return

	var stamina_cost: float = _get_stamina_cost()
	if stamina < stamina_cost:
		result_label.text = "Not enough stamina."
		return

	stamina -= stamina_cost
	cast_cooldown_remaining = _get_cast_cooldown()

	var catch_chance: float = clamp(BASE_CATCH_CHANCE * _get_stat_float("fish_chance", 1.0), 0.0, 1.0)
	if randf() > catch_chance:
		_refresh_ui("No bite this time.")
		return

	var player_data: Dictionary = Data.save_data.get("player", {})
	var location_id: String = String(player_data.get("current_location", "river"))
	var fish_id: int = DataManager.get_random_fish_id_for_location(location_id)
	if fish_id < 0:
		_refresh_ui("No fish available at this location.")
		return

	var fish_data_variant: Variant = DataManager.get_fish_data_by_id(fish_id)
	if typeof(fish_data_variant) != TYPE_DICTIONARY:
		_refresh_ui("Fish data is invalid.")
		return

	var fish_data: Dictionary = fish_data_variant
	var fish_name: String = String(fish_data.get("name", "Unknown fish"))

	var fish_size: int = _roll_from_range(_dict_from_variant(fish_data.get("size", {})), 1, 1)
	var value: int = _roll_from_range(_dict_from_variant(fish_data.get("value", {})), 1, 1)

	var rare_roll_chance: float = clamp(0.05 * _get_stat_float("rare_fish_chance", 1.0), 0.0, 0.9)
	var is_rare: bool = randf() <= rare_roll_chance
	if is_rare:
		value = int(round(float(value) * 2.0))
		fish_size = int(round(float(fish_size) * 1.2))

	InventoryManager.add_fish(fish_id, fish_size, value, location_id)

	_refresh_ui("You caught a %s!" % fish_name)
	_update_inventory_display()


func _on_inventory_button_pressed() -> void:
	inventory_dropdown.visible = not inventory_dropdown.visible
	if inventory_dropdown.visible:
		_update_inventory_display()


func _roll_from_range(range_data: Dictionary, fallback_min: int, fallback_max: int) -> int:
	var min_value: int = int(range_data.get("min", fallback_min))
	var max_value: int = int(range_data.get("max", fallback_max))
	if max_value < min_value:
		var tmp: int = max_value
		max_value = min_value
		min_value = tmp
	return randi_range(min_value, max_value)


func _dict_from_variant(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _get_cast_cooldown() -> float:
	var speed: float = max(_get_stat_float("fishing_speed", 1.0), 0.1)
	return max(1.0 / speed, MIN_CAST_INTERVAL)


func _get_stamina_cost() -> float:
	return BASE_STAMINA_COST


func _get_stat_float(stat_name: String, fallback: float) -> float:
	var current_stats_variant: Variant = Data.save_data["player"].get("current_stats", {})
	if typeof(current_stats_variant) == TYPE_DICTIONARY:
		var current_stats: Dictionary = current_stats_variant
		if current_stats.has(stat_name):
			return float(current_stats[stat_name])
	return fallback


func _ensure_player_defaults() -> void:
	if not Data.save_data.has("player"):
		Data.save_data["player"] = {}

	var player: Dictionary = Data.save_data["player"]
	if not player.has("coins"):
		player["coins"] = 0
	if not player.has("inventory"):
		player["inventory"] = []
	if not player.has("current_location"):
		player["current_location"] = "river"
	if not player.has("current_stats"):
		player["current_stats"] = {}

	Data.save_data["player"] = player

	var current_stats: Dictionary = Data.save_data["player"]["current_stats"]
	if current_stats.is_empty():
		UpgradeManager.apply_items()


func _pull_stamina_from_stats() -> void:
	max_stamina = max(_get_stat_float("fishing_stamina", 100.0), 1.0)
	stamina = max_stamina


func _refresh_ui(message: String) -> void:
	_update_coins_label()
	_update_stamina_label()
	result_label.text = message


func _update_coins_label() -> void:
	coins_label.text = "Coins: %d" % int(Data.save_data["player"].get("coins", 0))


func _update_stamina_label() -> void:
	stamina_label.text = "Stamina: %d / %d" % [int(round(stamina)), int(round(max_stamina))]


func _connect_sell_buttons() -> void:
	for i in range(1, 5):
		var fish_card: Control = grid_container.get_child(i - 1)
		if fish_card:
			var sell_button: Button = fish_card.find_child("SellButton")
			var sell_all_button: Button = fish_card.find_child("SellAllButton")
			var eat_button: Button = fish_card.find_child("EatButton")
			
			if sell_button and not sell_button.pressed.is_connected(Callable(self, "_on_sell_button_pressed")):
				sell_button.pressed.connect(Callable(self, "_on_sell_button_pressed").bindv([i - 1]))
			
			if sell_all_button and not sell_all_button.pressed.is_connected(Callable(self, "_on_sell_all_button_pressed")):
				sell_all_button.pressed.connect(Callable(self, "_on_sell_all_button_pressed").bindv([i - 1]))

			if eat_button and not eat_button.pressed.is_connected(Callable(self, "_on_eat_button_pressed")):
				eat_button.pressed.connect(Callable(self, "_on_eat_button_pressed").bindv([i - 1]))


func _on_sell_button_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= card_fish_ids.size():
		return

	var fish_id: int = card_fish_ids[card_index]
	if fish_id < 0:
		_refresh_ui("No fish to sell.")
		return

	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
	
	if fish_id < 0:
		_refresh_ui("Error: Fish not found.")
		return
	
	var inventory: Array = InventoryManager.get_inventory()
	var found_index: int = -1
	for i in range(inventory.size()):
		if inventory[i].get("fish_id") == fish_id:
			found_index = i
			break
	
	if found_index < 0:
		_refresh_ui("No %s to sell." % fish_name)
		return
	
	var fish_value: int = inventory[found_index].get("value", 0)
	var current_coins: int = int(Data.save_data["player"].get("coins", 0))
	Data.save_data["player"]["coins"] = current_coins + fish_value
	
	InventoryManager.remove_fish(found_index)
	
	_refresh_ui("Sold %s for %d coins." % [fish_name, fish_value])
	_update_inventory_display()


func _on_sell_all_button_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= card_fish_ids.size():
		return

	var fish_id: int = card_fish_ids[card_index]
	if fish_id < 0:
		_refresh_ui("No fish to sell.")
		return

	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
	
	if fish_id < 0:
		_refresh_ui("Error: Fish not found.")
		return
	
	var inventory: Array = InventoryManager.get_inventory()
	var total_value: int = 0
	var fish_count: int = 0
	var indices_to_remove: Array = []
	
	for i in range(inventory.size()):
		if inventory[i].get("fish_id") == fish_id:
			total_value += inventory[i].get("value", 0)
			fish_count += 1
			indices_to_remove.append(i)
	
	if fish_count == 0:
		_refresh_ui("No %s to sell." % fish_name)
		return
	
	var current_coins: int = int(Data.save_data["player"].get("coins", 0))
	Data.save_data["player"]["coins"] = current_coins + total_value
	
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for index in indices_to_remove:
		InventoryManager.remove_fish(index, false)

	File.save_game()
	
	_refresh_ui("Sold %d %s(s) for %d coins." % [fish_count, fish_name, total_value])
	_update_inventory_display()


func _on_eat_button_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= card_fish_ids.size():
		return

	var fish_id: int = card_fish_ids[card_index]
	if fish_id < 0:
		_refresh_ui("No fish to eat.")
		return

	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
	var stamina_gain: float = float(fish_data.get("eat_stamina", 5.0))

	var inventory: Array = InventoryManager.get_inventory()
	var found_index: int = -1
	for i in range(inventory.size()):
		if inventory[i].get("fish_id") == fish_id:
			found_index = i
			break

	if found_index < 0:
		_refresh_ui("No %s to eat." % fish_name)
		return

	InventoryManager.remove_fish(found_index)
	stamina = min(stamina + stamina_gain, max_stamina)
	_refresh_ui("You ate a %s! +%d stamina" % [fish_name, int(round(stamina_gain))])
	_update_inventory_display()

func _update_inventory_display() -> void:
	var inventory: Array = InventoryManager.get_inventory()
	var fish_counts: Dictionary = {}
	var fish_entries: Array = []
	
	for item in inventory:
		var fish_id: int = item.get("fish_id", -1)
		if not fish_counts.has(fish_id):
			fish_counts[fish_id] = 0
		fish_counts[fish_id] += 1

	for fish_id in fish_counts.keys():
		fish_entries.append({
			"fish_id": int(fish_id),
			"count": int(fish_counts[fish_id])
		})

	fish_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	
	for i in range(1, 5):
		var fish_card: Control = grid_container.get_child(i - 1)
		if fish_card:
			var fish_name_label: Label = fish_card.find_child("FishName")
			var count_label: Label = fish_card.find_child("CountLabel")
			var sell_button: Button = fish_card.find_child("SellButton")
			var sell_all_button: Button = fish_card.find_child("SellAllButton")
			var eat_button: Button = fish_card.find_child("EatButton")

			if (i - 1) < fish_entries.size():
				var entry: Dictionary = fish_entries[i - 1]
				var fish_id: int = int(entry.get("fish_id", -1))
				var count: int = int(entry.get("count", 0))
				card_fish_ids[i - 1] = fish_id

				var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
				var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
				var eat_stamina: int = int(round(float(fish_data.get("eat_stamina", 5.0))))

				if fish_name_label:
					fish_name_label.text = fish_name
				if count_label:
					count_label.text = "x%d" % count
				if sell_button:
					sell_button.disabled = false
				if sell_all_button:
					sell_all_button.disabled = false
				if eat_button:
					eat_button.disabled = false
					eat_button.text = "EAT (+%d stamina)" % eat_stamina
			else:
				card_fish_ids[i - 1] = -1
				if fish_name_label:
					fish_name_label.text = "Empty"
				if count_label:
					count_label.text = "x0"
				if sell_button:
					sell_button.disabled = true
				if sell_all_button:
					sell_all_button.disabled = true
				if eat_button:
					eat_button.disabled = true
					eat_button.text = "EAT (+0 stamina)"
