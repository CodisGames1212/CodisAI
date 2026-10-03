class_name CodisDemoRenderPreview
extends "res://addons/codisai/demo/scripts/chatbox.gd"

func _ready() -> void:
	super._ready()
	_theme_name = "Light"
	_add_message("user", "Show a short code example.")
	_add_message("assistant", "Here is **highlighted code**:\n```gdscript\n    func greet():\n        print(\"Hello!\")\n```\nSelect the text or use either copy icon.")
	_apply_appearance()
	call_deferred("_reflow")
