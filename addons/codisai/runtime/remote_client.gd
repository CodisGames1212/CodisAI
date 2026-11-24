class_name CodisAIRemote
extends Node

## Optional chat provider for the demo: talks to any OpenAI-compatible
## `/chat/completions` endpoint with the user's own API key instead of a local
## GGUF model. Requests are non-streaming; the reply arrives as one token
## signal followed by generation_finished, which the chatbox already handles.

signal token_received(text: String)
signal generation_finished(text: String, cancelled: bool)
signal generation_failed(message: String)
signal error_occurred(message: String)

const REQUEST_TIMEOUT_SECONDS := 180

var base_url := ""
var api_key := ""
var model := ""

var _request: HTTPRequest
var _busy := false
var _cancelled := false
var _last_error := ""


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.name = "ChatCompletionsRequest"
	_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


## Applies the provider settings. An empty base URL or model disables requests.
func configure(new_base_url: String, new_api_key: String, new_model: String) -> void:
	base_url = new_base_url.strip_edges()
	api_key = new_api_key.strip_edges()
	model = new_model.strip_edges()


func is_configured() -> bool:
	return not chat_url().is_empty() and not model.is_empty()


func is_generating() -> bool:
	return _busy


func get_last_error() -> String:
	return _last_error


## Builds the completions endpoint, accepting either a base URL or the full URL.
func chat_url() -> String:
	var base: String = base_url.strip_edges().trim_suffix("/")
	if base.is_empty():
		return ""
	if base.ends_with("/chat/completions"):
		return base
	return base + "/chat/completions"


func cancel_generation() -> void:
	if not _busy:
		return
	_cancelled = true
	_busy = false
	if _request != null:
		_request.cancel_request()
	generation_finished.emit("", true)


## Sends `[{role, content}, ...]` messages. Returns false when the request
## cannot start; the reason is available through get_last_error().
func send_chat(messages: Array, options: Dictionary = {}) -> bool:
	if _busy:
		return _fail("A request is already in progress.")
	var url: String = chat_url()
	if url.is_empty():
		return _fail("Set an API base URL in Settings before using a custom provider.")
	if model.is_empty():
		return _fail("Set an API model name in Settings before using a custom provider.")
	var payload: Dictionary = {"model": model, "messages": messages, "stream": false}
	if options.has("temperature"):
		payload["temperature"] = float(options["temperature"])
	if options.has("max_tokens"):
		payload["max_tokens"] = int(options["max_tokens"])
	var headers: PackedStringArray = ["Content-Type: application/json", "Accept: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	_cancelled = false
	_busy = true
	_last_error = ""
	var error: Error = _request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_busy = false
		return _fail("Provider request could not start: " + error_string(error))
	return true


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _cancelled:
		_cancelled = false
		return
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Provider request failed: " + _result_name(result))
		generation_failed.emit(_last_error)
		return
	var text_body: String = body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		_fail(_error_message(text_body, response_code))
		generation_failed.emit(_last_error)
		return
	var parsed: Variant = JSON.parse_string(text_body)
	var text: String = _message_text(parsed)
	if text.is_empty():
		_fail("The provider response did not contain a chat message.")
		generation_failed.emit(_last_error)
		return
	token_received.emit(text)
	generation_finished.emit(text, false)


## Returns the assistant text from a chat completion payload, or "" if absent.
static func _message_text(parsed: Variant) -> String:
	if not parsed is Dictionary:
		return ""
	var choices: Variant = parsed.get("choices", [])
	if not choices is Array or choices.is_empty():
		return ""
	var first: Variant = choices[0]
	if not first is Dictionary:
		return ""
	var message: Variant = first.get("message", {})
	if not message is Dictionary:
		return ""
	return String(message.get("content", "")).strip_edges()


## Extracts a provider error message, falling back to the HTTP status.
static func _error_message(text_body: String, response_code: int) -> String:
	var parsed: Variant = JSON.parse_string(text_body)
	if parsed is Dictionary:
		var error: Variant = parsed.get("error")
		if error is Dictionary:
			var detail: String = String(error.get("message", "")).strip_edges()
			if not detail.is_empty():
				return "Provider error (HTTP %d): %s" % [response_code, detail]
		var direct: String = String(parsed.get("message", "")).strip_edges()
		if not direct.is_empty():
			return "Provider error (HTTP %d): %s" % [response_code, direct]
	return "Provider error (HTTP %d). Check the base URL, model name and API key." % response_code


static func _result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "cannot connect to the provider"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "cannot resolve the provider host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "no response"
		HTTPRequest.RESULT_TIMEOUT:
			return "request timed out"
		_:
			return "result code %d" % result


func _fail(message: String) -> bool:
	_last_error = message
	error_occurred.emit(message)
	return false
