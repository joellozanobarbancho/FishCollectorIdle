extends Node

const API_KEY := "AIzaSyAN9OshKt3fPcqoJZB1ZZM-OQxVmlrZgcs"
const PROJECT_ID := "fishcollector-idle"
const FIRESTORE_BASE_URL := "https://firestore.googleapis.com/v1"
const SAVE_COLLECTION := "user_saves"
const CHAT_COLLECTION := "global_chat_messages"
const PRESENCE_COLLECTION := "online_presence"
const MAX_CHAT_MESSAGE_LENGTH := 180
const FIRESTORE_RULES_HINT := "Set Firestore Rules for user_saves/{userId}: allow read, write: if request.auth != null && request.auth.uid == userId;"
const CHAT_FIRESTORE_RULES_HINT := "Allow authenticated users on global_chat_messages and online_presence collections in Firestore Rules."

signal auth_succeeded(user_id: String)
signal auth_failed(message: String)
signal save_downloaded(success: bool)
signal save_uploaded(success: bool)

var id_token: String = ""
var local_id: String = ""
var user_email: String = ""
var last_auth_error: String = ""
var _quitting: bool = false
var _chat_permission_blocked: bool = false
var _chat_permission_logged_once: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false


func is_authenticated() -> bool:
	return not id_token.is_empty() and not local_id.is_empty()


func can_use_chat_features() -> bool:
	return is_authenticated() and not _chat_permission_blocked


func is_chat_permission_blocked() -> bool:
	return _chat_permission_blocked


func get_chat_rules_hint() -> String:
	return CHAT_FIRESTORE_RULES_HINT


func login(email: String, password: String) -> bool:
	return await _authenticate(email, password, false)


func register(email: String, password: String) -> bool:
	return await _authenticate(email, password, true)


func send_password_reset_email(email: String) -> bool:
	last_auth_error = ""
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=%s" % API_KEY
	var body := {
		"requestType": "PASSWORD_RESET",
		"email": email
	}
	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_POST,
		url,
		JSON.stringify(body),
		PackedStringArray(["Content-Type: application/json"])
	)

	if not response["ok"]:
		last_auth_error = String(response["message"])
		auth_failed.emit(last_auth_error)
		print("Error sending password reset email:", last_auth_error)
		return false

	print("Password reset email sent for:", email)
	return true


func _authenticate(email: String, password: String, is_signup: bool) -> bool:
	last_auth_error = ""
	var endpoint := "accounts:signUp" if is_signup else "accounts:signInWithPassword"
	var url := "https://identitytoolkit.googleapis.com/v1/%s?key=%s" % [endpoint, API_KEY]
	var body := {
		"email": email,
		"password": password,
		"returnSecureToken": true
	}
	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_POST,
		url,
		JSON.stringify(body),
		PackedStringArray(["Content-Type: application/json"])
	)

	if not response["ok"]:
		last_auth_error = String(response["message"])
		auth_failed.emit(last_auth_error)
		print("Error de auth:", last_auth_error)
		return false

	var json: Dictionary = response["json"]
	id_token = String(json.get("idToken", ""))
	local_id = String(json.get("localId", ""))
	user_email = String(json.get("email", email))
	_chat_permission_blocked = false
	_chat_permission_logged_once = false

	if id_token.is_empty() or local_id.is_empty():
		last_auth_error = "Auth response missing idToken/localId"
		auth_failed.emit(last_auth_error)
		return false

	auth_succeeded.emit(local_id)
	print("Auth correcta para uid:", local_id)

	if is_signup:
		if Data.save_data.is_empty():
			File.new_game()
		await upload_save()
	else:
		var download_ok: bool = await download_save()
		if not download_ok:
			last_auth_error = "Account data not found. Try to Register."
			auth_failed.emit(last_auth_error)
			return false

	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _quitting:
		_quitting = true
		call_deferred("_handle_quit_request")


func _handle_quit_request() -> void:
	File.save_game()
	if is_authenticated():
		await upload_save()
	get_tree().quit()


func _firestore_document_url() -> String:
	return "%s/projects/%s/databases/(default)/documents/%s/%s" % [
		FIRESTORE_BASE_URL,
		PROJECT_ID,
		SAVE_COLLECTION,
		local_id
	]


func _auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	])


func _firestore_collection_url(collection_name: String) -> String:
	return "%s/projects/%s/databases/(default)/documents/%s" % [
		FIRESTORE_BASE_URL,
		PROJECT_ID,
		collection_name
	]


func _firestore_collection_document_url(collection_name: String, document_id: String) -> String:
	return "%s/projects/%s/databases/(default)/documents/%s/%s" % [
		FIRESTORE_BASE_URL,
		PROJECT_ID,
		collection_name,
		document_id
	]


func send_global_chat_message(message_text: String, player_name: String) -> bool:
	if not can_use_chat_features():
		return false

	var trimmed_message: String = message_text.strip_edges()
	if trimmed_message.is_empty():
		return false

	if trimmed_message.length() > MAX_CHAT_MESSAGE_LENGTH:
		trimmed_message = trimmed_message.substr(0, MAX_CHAT_MESSAGE_LENGTH)

	var unix_time: int = int(Time.get_unix_time_from_system())
	var document_id: String = "%s_%d_%d" % [local_id, unix_time, randi_range(1000, 9999)]
	var payload := {
		"uid": local_id,
		"player_name": player_name,
		"message": trimmed_message,
		"created_at_unix": unix_time,
		"created_at_iso": Time.get_datetime_string_from_system()
	}

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_PATCH,
		_firestore_collection_document_url(CHAT_COLLECTION, document_id),
		JSON.stringify(Utilities.dict2fields(payload)),
		_auth_headers()
	)

	if response["ok"]:
		return true

	if _is_permission_error(response):
		_mark_chat_permission_error_once("No se pudo enviar chat")
		return false

	print("Error al enviar chat:", response["message"])
	return false


func fetch_recent_global_chat_messages(limit: int = 30) -> Array:
	var safe_limit: int = clamp(limit, 1, 100)
	if not can_use_chat_features():
		return []

	var url: String = "%s?pageSize=%d&orderBy=created_at_unix%%20desc" % [
		_firestore_collection_url(CHAT_COLLECTION),
		safe_limit
	]

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_GET,
		url,
		"",
		_auth_headers()
	)

	if not response["ok"]:
		if _is_permission_error(response):
			_mark_chat_permission_error_once("No se pudo leer chat")
			return []
		if int(response["code"]) != 404:
			print("Error al leer chat:", response["message"])
		return []

	var json: Dictionary = response["json"]
	if not json.has("documents") or typeof(json["documents"]) != TYPE_ARRAY:
		return []

	var messages: Array = []
	for doc_variant in json["documents"]:
		if typeof(doc_variant) != TYPE_DICTIONARY:
			continue
		var doc: Dictionary = doc_variant
		var parsed: Dictionary = Utilities.fields2dict(doc)
		if parsed.is_empty():
			continue
		messages.append(parsed)

	return messages


func update_chat_presence(player_name: String) -> void:
	if not can_use_chat_features():
		return

	var payload := {
		"uid": local_id,
		"player_name": player_name,
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"last_seen_iso": Time.get_datetime_string_from_system()
	}

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_PATCH,
		_firestore_collection_document_url(PRESENCE_COLLECTION, local_id),
		JSON.stringify(Utilities.dict2fields(payload)),
		_auth_headers()
	)

	if not response["ok"] and _is_permission_error(response):
		_mark_chat_permission_error_once("No se pudo actualizar presencia")
		return

	if not response["ok"] and int(response["code"]) != 404:
		print("Error al actualizar presencia:", response["message"])


func fetch_online_users_count(active_window_seconds: int = 90, max_docs: int = 100) -> int:
	if not can_use_chat_features():
		return 0

	var safe_max_docs: int = clamp(max_docs, 1, 200)
	var url: String = "%s?pageSize=%d&orderBy=last_seen_unix%%20desc" % [
		_firestore_collection_url(PRESENCE_COLLECTION),
		safe_max_docs
	]

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_GET,
		url,
		"",
		_auth_headers()
	)

	if not response["ok"]:
		if _is_permission_error(response):
			_mark_chat_permission_error_once("No se pudo leer presencia")
			return 0
		if int(response["code"]) != 404:
			print("Error al leer presencia:", response["message"])
		return 0

	var json: Dictionary = response["json"]
	if not json.has("documents") or typeof(json["documents"]) != TYPE_ARRAY:
		return 0

	var now_unix: int = int(Time.get_unix_time_from_system())
	var online_count: int = 0

	for doc_variant in json["documents"]:
		if typeof(doc_variant) != TYPE_DICTIONARY:
			continue
		var doc: Dictionary = doc_variant
		var parsed: Dictionary = Utilities.fields2dict(doc)
		var last_seen_unix: int = int(parsed.get("last_seen_unix", 0))
		if now_unix - last_seen_unix <= active_window_seconds:
			online_count += 1

	return online_count


func _mark_chat_permission_error_once(context_message: String) -> void:
	_chat_permission_blocked = true
	if _chat_permission_logged_once:
		return
	_chat_permission_logged_once = true
	print("%s: Missing or insufficient permissions." % context_message)
	print(CHAT_FIRESTORE_RULES_HINT)


func download_save() -> bool:
	if not is_authenticated():
		save_downloaded.emit(false)
		return false

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_GET,
		_firestore_document_url(),
		"",
		_auth_headers()
	)

	if not response["ok"]:
		if int(response["code"]) == 404:
			print("No existe save remoto, documento fue eliminado o no existe")
			save_downloaded.emit(false)
			return false

		if _is_permission_error(response):
			print("Permisos insuficientes en Firestore; usando guardado local.")
			print(FIRESTORE_RULES_HINT)
			if Data.save_data.is_empty():
				File.new_game()
			File.save_game()
			save_downloaded.emit(true)
			return true

		print("Error al descargar save:", response["message"])
		save_downloaded.emit(false)
		return false

	var json: Dictionary = response["json"]
	if not json.has("fields"):
		print("Documento remoto sin fields, creando save local inicial")
		if Data.save_data.is_empty():
			File.new_game()
		save_downloaded.emit(true)
		return true

	var remote_doc: Dictionary = Utilities.fields2dict(json)
	if remote_doc.has("save_data") and typeof(remote_doc["save_data"]) == TYPE_DICTIONARY:
		Data.save_data = remote_doc["save_data"]
		File.save_game()
		print("Save descargado desde Firestore")
		save_downloaded.emit(true)
		return true

	print("Documento remoto no contiene save_data válido")
	save_downloaded.emit(false)
	return false


func upload_save() -> void:
	if not is_authenticated():
		save_uploaded.emit(false)
		return

	if Data.save_data.is_empty():
		File.new_game()

	var payload := {
		"uid": local_id,
		"email": user_email,
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"updated_at_iso": Time.get_datetime_string_from_system(),
		"save_data": Data.save_data
	}

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_PATCH,
		_firestore_document_url(),
		JSON.stringify(Utilities.dict2fields(payload)),
		_auth_headers()
	)

	if response["ok"]:
		print("Save subido a Firestore")
		save_uploaded.emit(true)
	else:
		print("Error al subir save:", response["message"])
		if _is_permission_error(response):
			print(FIRESTORE_RULES_HINT)
		save_uploaded.emit(false)


func delete_user_data() -> bool:
	if not is_authenticated():
		print("No estás autenticado para borrar datos")
		return false

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_DELETE,
		_firestore_document_url(),
		"",
		_auth_headers()
	)

	if response["ok"]:
		print("Datos del usuario borrados de Firestore")
		return true
	else:
		print("Error al borrar datos del usuario:", response["message"])
		if _is_permission_error(response):
			print(FIRESTORE_RULES_HINT)
		return false


func _is_permission_error(response: Dictionary) -> bool:
	var code: int = int(response.get("code", 0))
	if code == 401 or code == 403:
		return true
	var message: String = String(response.get("message", "")).to_lower()
	return message.contains("insufficient permissions") or message.contains("permission_denied")


func _request_json(method: int, url: String, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var request := HTTPRequest.new()
	Utilities.fix_http_request(request)
	add_child(request)

	var request_error: int = request.request(url, headers, method, body)
	if request_error != OK:
		request.queue_free()
		return {
			"ok": false,
			"code": 0,
			"json": {},
			"message": "HTTPRequest error code %d" % request_error
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var response_code: int = int(result[1])
	var response_body: PackedByteArray = result[3]
	var response_text: String = response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var json: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	var ok: bool = response_code >= 200 and response_code < 300
	if ok:
		return {
			"ok": true,
			"code": response_code,
			"json": json,
			"message": ""
		}

	var error_message := "HTTP %d" % response_code
	if json.has("error") and typeof(json["error"]) == TYPE_DICTIONARY:
		var error_block: Dictionary = json["error"]
		error_message = String(error_block.get("message", error_message))

	return {
		"ok": false,
		"code": response_code,
		"json": json,
		"message": error_message
	}
