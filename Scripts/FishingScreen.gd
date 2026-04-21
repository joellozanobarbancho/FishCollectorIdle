extends Control

const BASE_CATCH_CHANCE: float = 0.85
const BASE_STAMINA_COST: float = 15.0
const BASE_REGEN_PER_SECOND: float = 0.1
const REEL_COOLDOWN_SECONDS: float = 1.0
const CHAT_POLL_INTERVAL_SECONDS: float = 2.0
const CHAT_MAX_MESSAGES_RENDERED: int = 30
const CHAT_MAX_MESSAGE_LENGTH: int = 180
const INVENTORY_CARD_SIZE := Vector2(112, 154)
const INVENTORY_CARD_IMAGE_SIZE := Vector2(0, 42)
const INVENTORY_CARD_PADDING := 3
const INVENTORY_CARD_SEPARATION := 2
const INVENTORY_CARD_FONT_SIZE := 8
const INVENTORY_GRID_SEPARATION := 6
const STORE_ITEM_PADDING := 8
const STORE_ITEM_SEPARATION := 4
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
@onready var store_dropdown: Control = $StoreDropdown
@onready var store_item_list: VBoxContainer = $StoreDropdown/MarginContainer/VBoxContainer/StorePanel/StoreMargin/ScrollContainer/ItemList
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
var card_fish_ids: Array[int] = []
var _message_revision: int = 0
var _cooldown_orb_activated: bool = false
var _chat_poll_timer: float = CHAT_POLL_INTERVAL_SECONDS
var _chat_request_in_flight: bool = false
var _presence_request_in_flight: bool = false
var _last_chat_render_signature: String = ""
var _pending_local_chat_messages: Array = []


func _ready() -> void:
	randomize()
	if Data.save_data.is_empty():
		File.load_game()
	_ensure_player_defaults()
	_pull_stamina_from_stats()
	store_dropdown.visible = false
	inventory_dropdown.visible = false
	social_dropdown.visible = false
	popup_layer.visible = false
	popup_panel.visible = false
	cooldown_orb.visible = false
	cooldown_orb.call("set_progress", 1.0)
	social_chat_log.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	_refresh_ui("Click to start fishing!")
	_build_store_items()
	_build_inventory_cards()
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
	if store_dropdown.visible or inventory_dropdown.visible or social_dropdown.visible:
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



func _on_store_button_pressed() -> void:
	store_dropdown.visible = not store_dropdown.visible
	if store_dropdown.visible:
		inventory_dropdown.visible = false
		social_dropdown.visible = false
		_build_store_items()


func _on_inventory_button_pressed() -> void:
	inventory_dropdown.visible = not inventory_dropdown.visible
	if inventory_dropdown.visible:
		store_dropdown.visible = false
		social_dropdown.visible = false
	if inventory_dropdown.visible:
		_update_inventory_display()


func _on_social_button_pressed() -> void:
	social_dropdown.visible = not social_dropdown.visible
	if social_dropdown.visible:
		store_dropdown.visible = false
		inventory_dropdown.visible = false
		_refresh_social_panel(true)
	else:
		_chat_poll_timer = CHAT_POLL_INTERVAL_SECONDS


func _build_store_items() -> void:
	for child in store_item_list.get_children():
		child.queue_free()

	for item_id_variant in DataManager.items_db.keys():
		var item_id: String = String(item_id_variant)
		var item_variant: Variant = DataManager.items_db[item_id_variant]
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item_data: Dictionary = item_variant
		store_item_list.add_child(_create_store_item_row(item_id, item_data))


func _create_store_item_row(item_id: String, item_data: Dictionary) -> PanelContainer:
	var owned_level: int = UpgradeManager.get_item_level(item_id)
	var max_level: int = int(item_data.get("max_level", 0))
	var is_maxed: bool = owned_level >= max_level

	var title_text: String = String(item_data.get("name", item_id))
	var level_text: String = "Lvl %d/%d" % [owned_level, max_level]
	var item_description: String = String(item_data.get("description", ""))
	var next_level_cost: int = -1

	if not is_maxed:
		var levels_variant: Variant = item_data.get("levels", [])
		if typeof(levels_variant) == TYPE_ARRAY:
			var levels: Array = levels_variant
			if owned_level >= 0 and owned_level < levels.size():
				var next_level_data_variant: Variant = levels[owned_level]
				if typeof(next_level_data_variant) == TYPE_DICTIONARY:
					var next_level_data: Dictionary = next_level_data_variant
					next_level_cost = int(next_level_data.get("cost", -1))

	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 86)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", STORE_ITEM_PADDING)
	margin.add_theme_constant_override("margin_top", STORE_ITEM_PADDING)
	margin.add_theme_constant_override("margin_right", STORE_ITEM_PADDING)
	margin.add_theme_constant_override("margin_bottom", STORE_ITEM_PADDING)
	row.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", STORE_ITEM_SEPARATION)
	margin.add_child(content)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	content.add_child(top_row)

	var title_label := Label.new()
	title_label.text = "%s (%s)" % [title_text, level_text]
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(title_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(72, 0)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy_button.text = "MAX"
	buy_button.disabled = true
	if not is_maxed:
		buy_button.text = "Buy"
		buy_button.disabled = false
		buy_button.pressed.connect(Callable(self, "_on_buy_store_item_pressed").bind(item_id))
	top_row.add_child(buy_button)

	var cost_label := Label.new()
	if is_maxed:
		cost_label.text = "Max level reached"
	else:
		cost_label.text = "Cost: %d" % max(next_level_cost, 0)
	content.add_child(cost_label)

	var description_label := Label.new()
	description_label.text = item_description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description_label)

	return row


func _on_buy_store_item_pressed(item_id: String) -> void:
	var item_variant: Variant = DataManager.items_db.get(item_id, null)
	if typeof(item_variant) != TYPE_DICTIONARY:
		return

	var item_data: Dictionary = item_variant
	var owned_level: int = UpgradeManager.get_item_level(item_id)
	var max_level: int = int(item_data.get("max_level", 0))
	if owned_level >= max_level:
		_build_store_items()
		return

	var next_cost: int = UpgradeManager.get_next_level_cost(item_id)
	var player_coins: int = int(Data.save_data["player"].get("coins", 0))
	if next_cost < 0:
		return
	if player_coins < next_cost:
		_refresh_ui("Not enough coins.")
		return

	var purchase_ok: bool = UpgradeManager.buy_item(item_id)
	if not purchase_ok:
		return

	_pull_stamina_from_stats()
	_refresh_hud_only()
	_build_store_items()


func _connect_social_controls() -> void:
	if social_send_button and not social_send_button.pressed.is_connected(Callable(self, "_on_social_send_button_pressed")):
		social_send_button.pressed.connect(Callable(self, "_on_social_send_button_pressed"))
	if social_message_input and not social_message_input.text_submitted.is_connected(Callable(self, "_on_social_message_submitted")):
		social_message_input.text_submitted.connect(Callable(self, "_on_social_message_submitted"))

func _build_inventory_cards() -> void:
	for child in grid_container.get_children():
		child.free()

	card_fish_ids.clear()
	var inventory: Array = InventoryManager.get_inventory()
	var fish_counts: Dictionary = {}
	for item in inventory:
		var fish_id: int = _normalized_fish_id(item.get("fish_id", -1))
		if fish_id < 0:
			continue
		if not fish_counts.has(fish_id):
			fish_counts[fish_id] = 0
		fish_counts[fish_id] += 1

	var fish_ids: Array[int] = _get_owned_fish_ids_from_counts(fish_counts)
	for fish_id in fish_ids:
		var count: int = int(fish_counts.get(fish_id, 0))
		card_fish_ids.append(fish_id)
		grid_container.add_child(_create_inventory_card(fish_id, card_fish_ids.size() - 1, count))


func _create_inventory_card(fish_id: int, card_index: int, count: int) -> PanelContainer:
	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
	var eat_stamina: int = int(round(float(fish_data.get("eat_stamina", 5.0))))
	var outline_texture: Texture2D = _get_outline_texture_for_fish(fish_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = INVENTORY_CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_margin := MarginContainer.new()
	card_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_margin.add_theme_constant_override("margin_left", INVENTORY_CARD_PADDING)
	card_margin.add_theme_constant_override("margin_top", INVENTORY_CARD_PADDING)
	card_margin.add_theme_constant_override("margin_right", INVENTORY_CARD_PADDING)
	card_margin.add_theme_constant_override("margin_bottom", INVENTORY_CARD_PADDING)
	card.add_child(card_margin)

	var card_column := VBoxContainer.new()
	card_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_column.add_theme_constant_override("separation", INVENTORY_CARD_SEPARATION)
	card_margin.add_child(card_column)

	var fish_sprite := TextureRect.new()
	fish_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fish_sprite.custom_minimum_size = INVENTORY_CARD_IMAGE_SIZE
	fish_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if outline_texture:
		fish_sprite.texture = outline_texture
	fish_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fish_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_column.add_child(fish_sprite)

	var name_label := Label.new()
	name_label.name = "FishName"
	name_label.text = fish_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", INVENTORY_CARD_FONT_SIZE)
	card_column.add_child(name_label)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.clip_text = true
	count_label.add_theme_font_size_override("font_size", INVENTORY_CARD_FONT_SIZE)
	card_column.add_child(count_label)

	var button_row := VBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", INVENTORY_CARD_SEPARATION)
	card_column.add_child(button_row)

	var sell_button := Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "SELL"
	sell_button.clip_text = true
	sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_button.add_theme_font_size_override("font_size", INVENTORY_CARD_FONT_SIZE)
	sell_button.pressed.connect(Callable(self, "_on_sell_button_pressed").bind(card_index))
	button_row.add_child(sell_button)

	var sell_all_button := Button.new()
	sell_all_button.name = "SellAllButton"
	sell_all_button.text = "SELL ALL"
	sell_all_button.clip_text = true
	sell_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_all_button.add_theme_font_size_override("font_size", INVENTORY_CARD_FONT_SIZE)
	sell_all_button.pressed.connect(Callable(self, "_on_sell_all_button_pressed").bind(card_index))
	button_row.add_child(sell_all_button)

	var eat_button := Button.new()
	eat_button.name = "EatButton"
	eat_button.text = "EAT (+%d stamina)" % eat_stamina
	eat_button.clip_text = true
	eat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eat_button.add_theme_font_size_override("font_size", INVENTORY_CARD_FONT_SIZE)
	eat_button.pressed.connect(Callable(self, "_on_eat_button_pressed").bind(card_index))
	button_row.add_child(eat_button)

	var disable_actions: bool = count <= 0
	sell_button.disabled = disable_actions
	sell_all_button.disabled = disable_actions
	eat_button.disabled = disable_actions

	return card


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
	var merged_messages: Array = _merge_pending_messages(chronological_messages)

	var signature: String = ""
	for entry_variant in merged_messages:
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
	for entry_variant in merged_messages:
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

	_append_local_chat_message(_current_player_name(), message_text)
	social_message_input.text = ""
	_chat_poll_timer = 0.2

	social_send_button.disabled = true
	var sent_ok: bool = await FirebaseManager.send_global_chat_message(message_text, _current_player_name())
	social_send_button.disabled = false

	if not sent_ok:
		social_online_label.text = "Message failed (local only)"
		return


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


func _append_local_chat_message(player_name: String, message: String) -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	_pending_local_chat_messages.append({
		"player_name": player_name,
		"message": message,
		"created_at_unix": now_unix,
		"_local_pending": true
	})
	var timestamp_text: String = _format_unix_time(now_unix)
	if social_chat_log.get_parsed_text().is_empty():
		social_chat_log.clear()
		social_chat_log.add_text("[%s] %s: %s\n" % [timestamp_text, player_name, message])
	else:
		social_chat_log.add_text("[%s] %s: %s\n" % [timestamp_text, player_name, message])
	if social_chat_log.get_line_count() > 0:
		social_chat_log.scroll_to_line(social_chat_log.get_line_count() - 1)


func _merge_pending_messages(remote_chronological: Array) -> Array:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var remaining_pending: Array = []

	for pending_variant in _pending_local_chat_messages:
		if typeof(pending_variant) != TYPE_DICTIONARY:
			continue
		var pending: Dictionary = pending_variant
		var pending_time: int = int(pending.get("created_at_unix", 0))
		if pending_time <= 0:
			continue

		# Drop very old pending items to avoid stale duplicates forever.
		if now_unix - pending_time > 30:
			continue

		var matched_remote: bool = false
		for remote_variant in remote_chronological:
			if typeof(remote_variant) != TYPE_DICTIONARY:
				continue
			var remote_entry: Dictionary = remote_variant
			if str(remote_entry.get("player_name", "")) != str(pending.get("player_name", "")):
				continue
			if str(remote_entry.get("message", "")) != str(pending.get("message", "")):
				continue
			var remote_time: int = int(remote_entry.get("created_at_unix", 0))
			if abs(remote_time - pending_time) <= 20:
				matched_remote = true
				break

		if not matched_remote:
			remaining_pending.append(pending)

	_pending_local_chat_messages = remaining_pending

	var merged: Array = remote_chronological.duplicate()
	for pending in _pending_local_chat_messages:
		merged.append(pending)

	merged.sort_custom(func(a, b):
		var ta: int = int(a.get("created_at_unix", 0))
		var tb: int = int(b.get("created_at_unix", 0))
		return ta < tb
	)

	return merged


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
	var speed_stat: float = max(_get_stat_float("fishing_speed", BASE_STAMINA_COST), 1.0)
	var speed_ratio: float = clamp(speed_stat / BASE_STAMINA_COST, 0.2, 3.0)
	return REEL_COOLDOWN_SECONDS * speed_ratio


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
	if not player.has("base_stats"):
		player["base_stats"] = {
			"fishing_stamina": 100.0,
			"fishing_stamina_regen": 0.1,
			"fishing_speed": 15.0,
			"chest_chance": 1.0,
			"fish_chance": 1.0,
			"rare_fish_chance": 1.0,
			"xp_multiplier": 1.0,
		}
	if not player.has("items_owned"):
		player["items_owned"] = {}
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


func _refresh_hud_only() -> void:
	_update_coins_label()
	_update_stamina_label()


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
		return

	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
	
	if fish_id < 0:
		return
	
	var inventory: Array = InventoryManager.get_inventory()
	var found_index: int = -1
	for i in range(inventory.size()):
		if _normalized_fish_id(inventory[i].get("fish_id", -1)) == fish_id:
			found_index = i
			break
	
	if found_index < 0:
		return
	
	var fish_value: int = inventory[found_index].get("value", 0)
	var current_coins: int = int(Data.save_data["player"].get("coins", 0))
	Data.save_data["player"]["coins"] = current_coins + fish_value
	
	InventoryManager.remove_fish(found_index)
	
	_refresh_hud_only()
	_update_inventory_display()


func _on_sell_all_button_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= card_fish_ids.size():
		return

	var fish_id: int = card_fish_ids[card_index]
	if fish_id < 0:
		return

	var fish_data: Dictionary = DataManager.get_fish_data_by_id(fish_id)
	var fish_name: String = String(fish_data.get("name", "Fish #%d" % fish_id))
	
	if fish_id < 0:
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
		return
	
	var current_coins: int = int(Data.save_data["player"].get("coins", 0))
	Data.save_data["player"]["coins"] = current_coins + total_value
	
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for index in indices_to_remove:
		InventoryManager.remove_fish(index, false)

	File.save_game()
	
	_refresh_hud_only()
	_update_inventory_display()


func _on_eat_button_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= card_fish_ids.size():
		return
	if stamina >= max_stamina:
		_refresh_ui("Stamina is already full.")
		return

	var fish_id: int = card_fish_ids[card_index]
	if fish_id < 0:
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
		return

	InventoryManager.remove_fish(found_index)
	stamina = min(stamina + stamina_gain, max_stamina)
	_refresh_hud_only()
	_update_inventory_display()

func _update_inventory_display() -> void:
	_build_inventory_cards()


func _get_owned_fish_ids_from_counts(fish_counts: Dictionary) -> Array[int]:
	var fish_ids: Array[int] = []
	for fish_id_variant in fish_counts.keys():
		fish_ids.append(int(fish_id_variant))
	fish_ids.sort()
	return fish_ids


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
