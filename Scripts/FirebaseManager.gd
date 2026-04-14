extends Node

const API_KEY := "AIzaSyAN9OshKt3fPcqoJZB1ZZM-OQxVmlrZgcs"
const PROJECT_ID := "fishcollector-idle"
const FIRESTORE_BASE_URL := "https://firestore.googleapis.com/v1"
const SAVE_COLLECTION := "user_saves"
const FIRESTORE_RULES_HINT := "Set Firestore Rules for user_saves/{userId}: allow read, write: if request.auth != null && request.auth.uid == userId;"

signal auth_succeeded(user_id: String)
signal auth_failed(message: String)
signal save_downloaded(success: bool)
signal save_uploaded(success: bool)

var id_token: String = ""
var local_id: String = ""
var user_email: String = ""
var last_auth_error: String = ""
var _quitting: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false


func is_authenticated() -> bool:
	return not id_token.is_empty() and not local_id.is_empty()


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
		await download_save()

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


func download_save() -> void:
	if not is_authenticated():
		save_downloaded.emit(false)
		return

	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_GET,
		_firestore_document_url(),
		"",
		_auth_headers()
	)

	if not response["ok"]:
		if int(response["code"]) == 404:
			print("No existe save remoto, creando documento inicial")
			if Data.save_data.is_empty():
				File.new_game()
			await upload_save()
			save_downloaded.emit(true)
			return

		if _is_permission_error(response):
			print("Permisos insuficientes en Firestore; usando guardado local.")
			print(FIRESTORE_RULES_HINT)
			if Data.save_data.is_empty():
				File.new_game()
			File.save_game()
			save_downloaded.emit(true)
			return

		print("Error al descargar save:", response["message"])
		save_downloaded.emit(false)
		return

	var json: Dictionary = response["json"]
	if not json.has("fields"):
		print("Documento remoto sin fields, creando save local inicial")
		if Data.save_data.is_empty():
			File.new_game()
		save_downloaded.emit(true)
		return

	var remote_doc: Dictionary = Utilities.fields2dict(json)
	if remote_doc.has("save_data") and typeof(remote_doc["save_data"]) == TYPE_DICTIONARY:
		Data.save_data = remote_doc["save_data"]
		File.save_game()
		print("Save descargado desde Firestore")
		save_downloaded.emit(true)
		return

	print("Documento remoto no contiene save_data válido")
	save_downloaded.emit(false)


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
