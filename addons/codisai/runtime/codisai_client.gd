class_name CodisAI
extends RefCounted

## Godot-facing facade for the CodisAI native GDExtension.
## The native runtime is required for actual model inference.

signal model_loaded(model_info: Dictionary)
signal model_unloaded
signal token_received(text: String)
signal generation_finished(text: String, cancelled: bool)
signal generation_failed(message: String)
signal error_occurred(message: String)

const NATIVE_CLASS := "CodisAINative"
const EXTENSION_PATH := "res://addons/codisai/native/codisai.gdextension"
static var _runtime_error := ""
static var _load_attempted := false
const DEFAULT_OPTIONS := {
	"context_size": 2048,
	"threads": 0,
	"gpu_layers": 0,
	"temperature": 0.7,
	"top_k": 40,
	"top_p": 0.95,
	"max_tokens": 256,
}

var _native: Object
var _model_path := ""
var _last_error := ""


func _init() -> void:
	if is_runtime_available():
		_native = ClassDB.instantiate(NATIVE_CLASS)
		_native.token_received.connect(_on_native_token)
		_native.generation_finished.connect(_on_native_finished)
		_native.generation_failed.connect(_on_native_failed)


## Returns true when the native CodisAI runtime is available in this build.
static func is_runtime_available() -> bool:
	if ClassDB.class_exists(NATIVE_CLASS):
		return true
	if not _load_attempted:
		_load_attempted = true
		var status := GDExtensionManager.load_extension(EXTENSION_PATH)
		if not ClassDB.class_exists(NATIVE_CLASS):
			_runtime_error = "CodisAI could not load its native runtime on %s (%s). Extension load status: %s. Check that the matching library and its dependencies are included in the export. See README.md." % [OS.get_name(), Engine.get_architecture_name(), status]
	return ClassDB.class_exists(NATIVE_CLASS)


static func get_runtime_error() -> String:
	if is_runtime_available():
		return ""
	return _runtime_error


## Loads a local GGUF model. This operation may take several seconds.
func load_model(path: String, options: Dictionary = {}) -> bool:
	if _native == null:
		return _fail(get_runtime_error())
	if not path.to_lower().ends_with(".gguf"):
		return _fail("CodisAI supports GGUF model files; choose a .gguf file.")
	if not FileAccess.file_exists(path):
		return _fail("Model file does not exist: %s" % path)
	if _native.is_generating():
		return _fail("Cannot replace the model while generation is running.")

	var settings := DEFAULT_OPTIONS.duplicate()
	settings.merge(options, true)
	var native_path := ProjectSettings.globalize_path(path)
	if not _native.load_model(native_path, settings):
		return _fail(_native.get_last_error())

	_model_path = path
	_last_error = ""
	model_loaded.emit(_native.get_model_info())
	return true


## Unloads the current model and releases its native memory.
func unload_model() -> void:
	if _native == null:
		return
	_native.cancel_generation()
	_native.unload_model()
	_model_path = ""
	model_unloaded.emit()


## Starts generation on the native worker thread. Text arrives through token_received.
func generate_async(prompt: String, options: Dictionary = {}) -> bool:
	if _native == null:
		return _fail(get_runtime_error())
	if not _native.is_model_loaded():
		return _fail("Load a GGUF model before generating text.")
	if prompt.strip_edges().is_empty():
		return _fail("Prompt cannot be empty.")
	if _native.is_generating():
		return _fail("A generation is already in progress.")

	var settings := DEFAULT_OPTIONS.duplicate()
	settings.merge(options, true)
	if not _native.generate_async(prompt, settings):
		return _fail(_native.get_last_error())
	_last_error = ""
	return true


## Requests cancellation. The native runtime stops at the next inference checkpoint.
func cancel_generation() -> void:
	if _native != null:
		_native.cancel_generation()


func is_model_loaded() -> bool:
	return _native != null and _native.is_model_loaded()


func is_generating() -> bool:
	return _native != null and _native.is_generating()


func get_model_info() -> Dictionary:
	if not is_model_loaded():
		return {}
	return _native.get_model_info()


func get_model_path() -> String:
	return _model_path


func get_last_error() -> String:
	return _last_error


func _fail(message: String) -> bool:
	_last_error = message
	error_occurred.emit(message)
	return false


func _on_native_token(text: String) -> void:
	token_received.emit(text)


func _on_native_finished(text: String, cancelled: bool) -> void:
	generation_finished.emit(text, cancelled)


func _on_native_failed(message: String) -> void:
	_last_error = message
	generation_failed.emit(message)
	error_occurred.emit(message)
