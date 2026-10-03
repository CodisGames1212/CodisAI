class_name TestCodisRecent
extends Node

const STORE = preload("res://addons/codisai/demo/scripts/recent_store.gd")
const CHAT = preload("res://addons/codisai/demo/scripts/chatbox.gd")

func test_recent_json_roundtrip_and_remove() -> void:
	var directory: String = "user://recent_tests"
	var id: String = "test_%d" % Time.get_ticks_usec()
	var record: Dictionary = {"prompt": "What is the moon?", "model": "Qwen 2.5", "modified": 123, "date": "9/9/26", "history": [{"role": "user", "content": "What is the moon?"}]}
	assert(STORE.save_record(directory, id, record) == OK)
	var found: bool = false
	for saved: Dictionary in STORE.records(directory):
		if saved["id"] == id:
			assert(saved["prompt"] == record["prompt"])
			assert(saved["history"] == record["history"])
			found = true
	assert(found)
	assert(STORE.remove_record(directory, id) == OK)
	assert(not FileAccess.file_exists(directory.path_join(id + ".json")))
	assert(STORE.remove_record(directory, "../settings") == ERR_INVALID_PARAMETER)

func test_recent_popup_and_conversation_restore() -> void:
	var chat: CHAT = CHAT.new()
	get_tree().root.add_child(chat)
	await get_tree().process_frame
	assert(chat._recent_dir.ends_with("CodisGames/CodisAI/recent"))
	chat._refresh_recent()
	assert(chat._recent_grid.columns == 4)
	assert((chat._recent_grid.get_child(0) as Label).text == "Prompt")
	assert((chat._recent_grid.get_child(1) as Label).text == "Model")
	assert((chat._recent_grid.get_child(2) as Label).text == "Modified")
	chat._recent_dir = "user://recent_tests"
	var id: String = "ui_%d" % Time.get_ticks_usec()
	assert(STORE.save_record(chat._recent_dir, id, {"prompt": "what is the moon", "model": "Qwen 2.5", "date": "9/9/26", "history": []}) == OK)
	chat._refresh_recent()
	assert(chat._recent_grid.get_child_count() == 8)
	assert((chat._recent_grid.get_child(7) as Button).text == "X")
	chat._remove_recent(id)
	assert(chat._recent_grid.get_child_count() == 4)
	chat._open_recent({"id": "fixture", "history": [{"role": "user", "content": "Hello"}], "messages": [{"role": "user", "text": "Hello"}, {"role": "assistant", "text": "Hi"}]})
	assert(chat._history.size() == 1)
	assert(chat._messages.size() == 2)
	assert(chat._recent_id == "fixture")
	chat._new_chat()
	assert(chat._recent_id.is_empty())
	chat.queue_free()
	await get_tree().process_frame
