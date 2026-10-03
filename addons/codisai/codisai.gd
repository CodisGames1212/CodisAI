@tool
extends EditorPlugin

## CodisAI editor plugin: adds a tool-menu shortcut that opens the local chat
## demo. The native GDExtension itself is loaded automatically by Godot from its
## .gdextension manifest; this plugin only provides the editor convenience entry.

const DEMO_SCENE := "res://addons/codisai/demo/scenes/chat.tscn"
const TOOL_LABEL := "CodisAI: Open Local Chat Demo"


func _enter_tree() -> void:
	add_tool_menu_item(TOOL_LABEL, _open_demo)


func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_LABEL)


func _open_demo() -> void:
	if ResourceLoader.exists(DEMO_SCENE):
		EditorInterface.open_scene_from_path(DEMO_SCENE)