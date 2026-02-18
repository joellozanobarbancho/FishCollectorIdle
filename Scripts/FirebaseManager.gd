extends Node

const API_KEY := "TU_API_KEY"
const DB_URL := "https://TU_PROYECTO.firebaseio.com"

var id_token: String = ""
var local_id: String = ""

func login(email: String, password: String) -> void:
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=%s" % API_KEY
	var body = {
		"email": email,
		"password": password,
		"returnSecureToken": true
	}

	var request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(_on_login_response)

	request.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)


func _on_login_response(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())

	if json.has("idToken"):
		id_token = json["idToken"]
		local_id = json["localId"]
		print("Login correcto")

		download_save()
	else:
		print("Error al iniciar sesión: ", json)


func download_save() -> void:
	var url = "%s/users/%s/save.json?auth=%s" % [DB_URL, local_id, id_token]

	var request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(_on_download_response)
	request.request(url)


func _on_download_response(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())

	if typeof(json) == TYPE_DICTIONARY:
		print("Guardado descargado")
		File.data = json
	else:
		print("No existe guardado remoto, creando uno nuevo")
		File.new_game()
		upload_save()


func upload_save() -> void:
	var url = "%s/users/%s/save.json?auth=%s" % [DB_URL, local_id, id_token]

	var request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(_on_upload_response)

	request.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
		JSON.stringify(File.data)
	)


func _on_upload_response(result, response_code, headers, body):
	print("Guardado subido correctamente")
