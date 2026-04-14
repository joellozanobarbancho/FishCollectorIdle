extends Control

const BASE_CATCH_CHANCE: float = 0.85
const BASE_STAMINA_COST: float = 10.0
const BASE_REGEN_PER_SECOND: float = 6.0
const MIN_CAST_INTERVAL: float = 0.15

@onready var coins_label: Label = $Panel/MarginContainer/VBoxContainer/CoinsLabel
@onready var stamina_label: Label = $Panel/MarginContainer/VBoxContainer/StaminaLabel
@onready var fish_button: Button = $Panel/MarginContainer/VBoxContainer/FishButton
@onready var result_label: Label = $Panel/MarginContainer/VBoxContainer/ResultLabel
@onready var inventory_dropdown: Control = $InventoryDropdown

var cast_cooldown_remaining: float = 0.0
var stamina: float = 100.0
var max_stamina: float = 100.0


func _ready() -> void:
	randomize()
	if Data.save_data.is_empty():
		File.load_game()
	_ensure_player_defaults()
	_pull_stamina_from_stats()
	inventory_dropdown.visible = false
	_refresh_ui("Ready to fish.")


func _process(delta: float) -> void:
	if cast_cooldown_remaining > 0.0:
		cast_cooldown_remaining = max(cast_cooldown_remaining - delta, 0.0)

	var regen_rate: float = BASE_REGEN_PER_SECOND + (_get_stat_float("fishing_stamina_regen", 0.1) * 10.0)
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

	var fish_data_variant: Variant = DataManager.fish_db.get(fish_id, {})
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

	var current_coins: int = int(Data.save_data["player"].get("coins", 0))
	Data.save_data["player"]["coins"] = current_coins + value
	InventoryManager.add_fish(fish_id, fish_size, value, location_id)

	var rarity_text: String = " (Rare!)" if is_rare else ""
	_refresh_ui("Caught %s%s - Size %d, +%d coins" % [fish_name, rarity_text, fish_size, value])


func _on_inventory_button_pressed() -> void:
	inventory_dropdown.visible = not inventory_dropdown.visible


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
	var speed: float = max(_get_stat_float("fishing_speed", 1.0), 0.1)
	return max(BASE_STAMINA_COST / speed, 1.0)


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
