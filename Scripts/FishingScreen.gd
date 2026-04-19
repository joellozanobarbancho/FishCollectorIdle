extends Control

const BASE_CATCH_CHANCE: float = 0.85
const BASE_STAMINA_COST: float = 15.0
const BASE_REGEN_PER_SECOND: float = 0.1
const REEL_COOLDOWN_SECONDS: float = 1.0
const INVENTORY_CARD_FISH_NAMES: Array[String] = ["Catfish", "Goldfish", "Rainbow Trout", "Angelfish"]
const CHAT_POLL_INTERVAL_SECONDS: float = 2.0
const CHAT_MAX_MESSAGES_RENDERED: int = 30
const CHAT_MAX_MESSAGE_LENGTH: int = 180
const POPUP_HALF_WIDTH: float = 200.0
const POPUP_HALF_HEIGHT_TEXT_ONLY: float = 34.0
const POPUP_HALF_HEIGHT_WITH_FISH: float = 82.0
const FISH_OUTLINE_TEXTURES := {
	"Anchovy": "res://Assets/fish/Salt Water/Anchovy Outline.png",
	"Clownfish": "res://Assets/fish/Salt Water/Clownfish Outline.png",
	"Crab": "res://Assets/fish/Salt Water/Crab - Dungeness Outline.png",
	"Pufferfish": "res://Assets/fish/Salt Water/Pufferfish Outline.png",
	"Surgeonfish": "res://Assets/fish/Salt Water/Surgeonfish Outline.png",
	"Goldfish": "res://Assets/fish/Fresh Water/Goldfish Outline.png",
	"Bass": "res://Assets/fish/Fresh Water/Bass Outline.png",
	"Catfish": "res://Assets/fish/Fresh Water/Catfish Outline.png",
	"Angelfish": "res://Assets/fish/Fresh Water/Angelfish Outline.png",
	"Rainbow Trout": "res://Assets/fish/Fresh Water/Rainbow Trout Outline.png"
}

@onready var coins_label: Label = $TopHud/CoinsLabel
@onready var stamina_label: Label = $TopHud/StaminaLabel
@onready var cooldown_orb: Control = $CooldownOrb
@onready var catch_area: Control = $CatchArea
@onready var popup_layer: CanvasLayer = $MessagePopupLayer
@onready var popup_panel: PanelContainer = $MessagePopupLayer/PopupContainer
@onready var popup_label: Label = $MessagePopupLayer/PopupContainer/PopupMargin/PopupContent/PopupLabel
@onready var popup_fish_sprite: TextureRect = $MessagePopupLayer/PopupContainer/PopupMargin/PopupContent/PopupFishSprite
@onready var inventory_dropdown: Control = $InventoryDropdown
@onready var grid_container: GridContainer = $InventoryDropdown/MarginContainer/VBoxContainer/InventoryPanel/InventoryMargin/ScrollContainer/GridContainer
@onready var social_dropdown: Control = $SocialDropdown
@onready var social_online_label: Label = $SocialDropdown/MarginContainer/VBoxContainer/HeaderPanel/HeaderMargin/HeaderRow/OnlineLabel
@onready var social_chat_log: RichTextLabel = $SocialDropdown/MarginContainer/VBoxContainer/ChatPanel/ChatMargin/ChatLog
@onready var social_message_input: LineEdit = $SocialDropdown/MarginContainer/VBoxContainer/InputRow/MessageInput
@onready var social_send_button: Button = $SocialDropdown/MarginContainer/VBoxContainer/InputRow/SendButton

var cast_cooldown_remaining: float = 0.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var card_fish_ids: Array[int] = [-1, -1, -1, -1]
var _message_revision: int = 0
var _cooldown_orb_activated: bool = false
var _chat_poll_timer: float = CHAT_POLL_INTERVAL_SECONDS
var _chat_request_in_flight: bool = false
var _presence_request_in_flight: bool = false
var _last_chat_render_signature: String = ""


func _ready() -> void:
	randomize()
	if Data.save_data.is_empty():
		File.load_game()
	_ensure_player_defaults()
	_pull_stamina_from_stats()
	inventory_dropdown.visible = false
	social_dropdown.visible = false
	popup_layer.visible = false
	popup_panel.visible = false
	cooldown_orb.visible = false
	cooldown_orb.call("set_progress", 1.0)
	_refresh_ui("Click to start fishing!")
	_connect_sell_buttons()
	_connect_social_controls()


func _process(delta: float) -> void:
	if cast_cooldown_remaining > 0.0:
		cast_cooldown_remaining = max(cast_cooldown_remaining - delta, 0.0)

	var regen_rate: float = max(_get_stat_float("fishing_stamina_regen", BASE_REGEN_PER_SECOND), 0.0)
	stamina = min(stamina + regen_rate * delta, max_stamina)

	var cooldown_ratio: float = 1.0 - (cast_cooldown_remaining / REEL_COOLDOWN_SECONDS)
	cooldown_orb.call("set_progress", clamp(cooldown_ratio, 0.0, 1.0))
	if _cooldown_orb_activated and cast_cooldown_remaining <= 0.0:
		cooldown_orb.visible = false

	_update_social_chat_polling(delta)

	_update_coins_label()
	_update_stamina_label()


func _input(event: InputEvent) -> void:
	if inventory_dropdown.visible or social_dropdown.visible:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var click_event: InputEventMouseButton = event
	var catch_rect: Rect2 = catch_area.get_global_rect()
	if catch_rect.has_point(click_event.global_position):
		_activate_cooldown_orb_once()
		_on_fish_button_pressed()


func _activate_cooldown_orb_once() -> void:
	if _cooldown_orb_activated:
		return
	_cooldown_orb_activated = true
	cooldown_orb.visible = true
	cooldown_orb.call("set_progress", 1.0)


func _on_fish_button_pressed() -> void:
	if cast_cooldown_remaining > 0.0:
		return

	var stamina_cost: float = _get_stamina_cost()
	if stamina < stamina_cost:
		_refresh_ui("Not enough stamina.")
		return

	stamina -= stamina_cost
	cast_cooldown_remaining = _get_cast_cooldown()
	if _cooldown_orb_activated:
		cooldown_orb.visible = true

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

	_refresh_ui("You caught a %s!" % fish_name, fish_id)
	_update_inventory_display()


func _on_inventory_button_pressed() -> void:
	inventory_dropdown.visible = not inventory_dropdown.visible
	if inventory_dropdown.visible:
		social_dropdown.visible = false
	if inventory_dropdown.visible:
		_update_inventory_display()


func _on_social_button_pressed() -> void:
	social_dropdown.visible = not social_dropdown.visible
	if social_dropdown.visible:
		inventory_dropdown.visible = false
		_refresh_social_panel(true)
	else:
		_chat_poll_timer = CHAT_POLL_INTERVAL_SECONDS


func _connect_social_controls() -> void:
	if social_send_button and not social_send_button.pressed.is_connected(Callable(self, "_on_social_send_button_pressed")):
		social_send_button.pressed.connect(Callable(self, "_on_social_send_button_pressed"))
	if social_message_input and not social_message_input.text_submitted.is_connected(Callable(self, "_on_social_message_submitted")):
		social_message_input.text_submitted.connect(Callable(self, "_on_social_message_submitted"))


func _update_social_chat_polling(delta: float) -> void:
	if not social_dropdown.visible:
		return
	if not FirebaseManager.is_authenticated():
		social_online_label.text = "Login required"
		return
	if not FirebaseManager.can_use_chat_features():
		_show_chat_permission_needed_message()
		return

	_chat_poll_timer -= delta
	if _chat_poll_timer > 0.0:
		return

	_chat_poll_timer = CHAT_POLL_INTERVAL_SECONDS
	_refresh_social_panel()


func _refresh_social_panel(force_refresh_messages: bool = false) -> void:
	if not social_dropdown.visible:
		return
	if not FirebaseManager.is_authenticated():
		social_online_label.text = "Login required"
		return
	if not FirebaseManager.can_use_chat_features():
		_show_chat_permission_needed_message()
		return

	if not _presence_request_in_flight:
		_presence_request_in_flight = true
		_refresh_presence_async()

	if force_refresh_messages or not _chat_request_in_flight:
		_chat_request_in_flight = true
		_refresh_chat_messages_async()


func _refresh_presence_async() -> void:
	var player_name: String = _current_player_name()
	await FirebaseManager.update_chat_presence(player_name)
	var online_count: int = await FirebaseManager.fetch_online_users_count(90, 100)
	social_online_label.text = "Online now: %d" % online_count
	_presence_request_in_flight = false


func _refresh_chat_messages_async() -> void:
	var messages: Array = await FirebaseManager.fetch_recent_global_chat_messages(CHAT_MAX_MESSAGES_RENDERED)
	_render_social_messages(messages)
	_chat_request_in_flight = false


func _render_social_messages(messages_desc: Array) -> void:
	var chronological_messages: Array = messages_desc.duplicate()
	chronological_messages.reverse()

	var signature: String = ""
	for entry_variant in chronological_messages:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		signature += "%s|%s|%s\n" % [
			str(entry.get("created_at_unix", 0)),
			str(entry.get("player_name", "")),
			str(entry.get("message", ""))
		]

	if signature == _last_chat_render_signature:
		return
	_last_chat_render_signature = signature

	social_chat_log.clear()
	for entry_variant in chronological_messages:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var player_name: String = str(entry.get("player_name", "Player"))
		var message: String = str(entry.get("message", ""))
		var timestamp: int = int(entry.get("created_at_unix", 0))
		var time_text: String = _format_unix_time(timestamp)
		social_chat_log.add_text("[%s] %s: %s\n" % [time_text, player_name, message])

	if social_chat_log.get_line_count() > 0:
		social_chat_log.scroll_to_line(social_chat_log.get_line_count() - 1)


func _on_social_send_button_pressed() -> void:
	if not FirebaseManager.is_authenticated():
		social_online_label.text = "Login required"
		return
	if not FirebaseManager.can_use_chat_features():
		_show_chat_permission_needed_message()
		return

	var message_text: String = social_message_input.text.strip_edges()
	if message_text.is_empty():
		return

	if message_text.length() > CHAT_MAX_MESSAGE_LENGTH:
		message_text = message_text.substr(0, CHAT_MAX_MESSAGE_LENGTH)

	social_send_button.disabled = true
	var sent_ok: bool = await FirebaseManager.send_global_chat_message(message_text, _current_player_name())
	social_send_button.disabled = false

	if not sent_ok:
		social_online_label.text = "Message failed"
		return

	social_message_input.text = ""
	_chat_poll_timer = CHAT_POLL_INTERVAL_SECONDS
	_refresh_social_panel(true)


func _on_social_message_submitted(_new_text: String) -> void:
	_on_social_send_button_pressed()


func _current_player_name() -> String:
	var player_data: Dictionary = Data.save_data.get("player", {})
	var configured_name: String = str(player_data.get("name", "")).strip_edges()
	if configured_name.is_empty():
		return "Player"
	return configured_name


func _format_unix_time(unix_timestamp: int) -> String:
	if unix_timestamp <= 0:
		return "--:--"
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(unix_timestamp)
	return "%02d:%02d" % [int(datetime.get("hour", 0)), int(datetime.get("minute", 0))]


func _show_chat_permission_needed_message() -> void:
	social_online_label.text = "Chat blocked by Firestore rules"
	if social_chat_log.get_parsed_text().is_empty():
		social_chat_log.clear()
		social_chat_log.add_text("Configure Firestore rules for global_chat_messages and online_presence.\n")


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
	return REEL_COOLDOWN_SECONDS


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


func _refresh_ui(message: String, caught_fish_id: int = -1) -> void:
	_update_coins_label()
	_update_stamina_label()
	_show_popup_message(message, caught_fish_id)


func _show_popup_message(message: String, caught_fish_id: int = -1) -> void:
	_message_revision += 1
	var current_revision: int = _message_revision

	popup_label.text = message
	var popup_texture: Texture2D = _get_outline_texture_for_fish(caught_fish_id)
	if popup_texture:
		popup_fish_sprite.texture = popup_texture
		popup_fish_sprite.visible = true
		_set_popup_half_height(POPUP_HALF_HEIGHT_WITH_FISH)
	else:
		popup_fish_sprite.texture = null
		popup_fish_sprite.visible = false
		_set_popup_half_height(POPUP_HALF_HEIGHT_TEXT_ONLY)
	popup_layer.visible = true
	popup_panel.visible = true

	await get_tree().create_timer(1.5).timeout
	if current_revision == _message_revision:
		popup_panel.visible = false
		popup_layer.visible = false


func _get_outline_texture_for_fish(fish_id: int) -> Texture2D:
	if fish_id < 0:
		return null
	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	if fish_data.is_empty():
		return null

	var fish_name: String = String(fish_data.get("name", ""))
	if not FISH_OUTLINE_TEXTURES.has(fish_name):
		return null

	var outline_path: String = String(FISH_OUTLINE_TEXTURES[fish_name])
	var loaded: Variant = load(outline_path)
	if loaded is Texture2D:
		return loaded
	return null


func _set_popup_half_height(half_height: float) -> void:
	popup_panel.offset_left = -POPUP_HALF_WIDTH
	popup_panel.offset_right = POPUP_HALF_WIDTH
	popup_panel.offset_top = -half_height
	popup_panel.offset_bottom = half_height


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
		if _normalized_fish_id(inventory[i].get("fish_id", -1)) == fish_id:
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
		if _normalized_fish_id(inventory[i].get("fish_id", -1)) == fish_id:
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
		if _normalized_fish_id(inventory[i].get("fish_id", -1)) == fish_id:
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
	
	for item in inventory:
		var fish_id: int = _normalized_fish_id(item.get("fish_id", -1))
		if not fish_counts.has(fish_id):
			fish_counts[fish_id] = 0
		fish_counts[fish_id] += 1
	
	for i in range(1, 5):
		var fish_card: Control = grid_container.get_child(i - 1)
		if fish_card:
			var fish_name_label: Label = fish_card.find_child("FishName")
			var count_label: Label = fish_card.find_child("CountLabel")
			var sell_button: Button = fish_card.find_child("SellButton")
			var sell_all_button: Button = fish_card.find_child("SellAllButton")
			var eat_button: Button = fish_card.find_child("EatButton")

			var target_fish_name: String = INVENTORY_CARD_FISH_NAMES[i - 1]
			var target_fish_id: int = _get_fish_id_by_name(target_fish_name)
			var count: int = int(fish_counts.get(target_fish_id, 0))
			card_fish_ids[i - 1] = target_fish_id

			var fish_data: Dictionary = DataManager.get_fish_data_by_id(target_fish_id)
			var eat_stamina: int = int(round(float(fish_data.get("eat_stamina", 5.0))))

			if fish_name_label:
				fish_name_label.text = target_fish_name
			if count_label:
				count_label.text = "x%d" % count

			var disable_actions: bool = target_fish_id < 0 or count <= 0
			if sell_button:
				sell_button.disabled = disable_actions
			if sell_all_button:
				sell_all_button.disabled = disable_actions
			if eat_button:
				eat_button.disabled = disable_actions
				eat_button.text = "EAT (+%d stamina)" % eat_stamina


func _get_fish_id_by_name(fish_name: String) -> int:
	for fish_id_key in DataManager.fish_db.keys():
		var fish_id: int = _normalized_fish_id(fish_id_key)
		if fish_id < 0:
			continue
		var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
		if String(fish_data.get("name", "")) == fish_name:
			return fish_id
	return -1


func _normalized_fish_id(raw_fish_id: Variant) -> int:
	match typeof(raw_fish_id):
		TYPE_INT:
			return raw_fish_id
		TYPE_FLOAT:
			return int(raw_fish_id)
		TYPE_STRING:
			if String(raw_fish_id).is_valid_int():
				return int(raw_fish_id)
	return -1
