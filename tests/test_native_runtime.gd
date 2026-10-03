class_name TestCodisNativeRuntime
extends Node

const CLIENT = preload("res://addons/codisai/runtime/codisai_client.gd")

func test_native_runtime_registration() -> void:
	assert(CLIENT.is_runtime_available(), CLIENT.get_runtime_error())
	assert(CLIENT.get_runtime_error().is_empty())
	var runtime: CLIENT = CLIENT.new()
	assert(runtime._native != null)
	assert(not runtime.is_model_loaded())
	runtime.unload_model()
	print("Native runtime loading checks passed on %s (%s)" % [OS.get_name(), Engine.get_architecture_name()])
