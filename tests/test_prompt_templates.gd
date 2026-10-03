extends Node

const PROMPT = preload("res://addons/codisai/demo/scripts/chat_prompt.gd")
const CATALOG = preload("res://addons/codisai/demo/scripts/model_catalog.gd")
const TEMPLATES: Array[String] = ["chatml", "zephyr", "llama3", "phi3", "gemma", "mistral"]


func test_exact_multiturn_templates() -> void:
	var history: Array = [
		{"role": "user", "content": "Hello"},
		{"role": "assistant", "content": "Hi"},
		{"role": "user", "content": "More"},
	]
	var system: String = CATALOG.SYSTEM_PROMPT
	var expected: Dictionary = {
		"chatml": "<|im_start|>system\n" + system + "<|im_end|>\n<|im_start|>user\nHello<|im_end|>\n<|im_start|>assistant\nHi<|im_end|>\n<|im_start|>user\nMore<|im_end|>\n<|im_start|>assistant\n",
		"zephyr": "<|system|>\n" + system + "</s>\n<|user|>\nHello</s>\n<|assistant|>\nHi</s>\n<|user|>\nMore</s>\n<|assistant|>\n",
		"llama3": "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n" + system + "<|eot_id|><|start_header_id|>user<|end_header_id|>\n\nHello<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\nHi<|eot_id|><|start_header_id|>user<|end_header_id|>\n\nMore<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n",
		"phi3": "<|system|>\n" + system + "<|end|>\n<|user|>\nHello<|end|>\n<|assistant|>\nHi<|end|>\n<|user|>\nMore<|end|>\n<|assistant|>\n",
		"gemma": "<bos><start_of_turn>user\n" + system + "\n\nHello<end_of_turn>\n<start_of_turn>model\nHi<end_of_turn>\n<start_of_turn>user\nMore<end_of_turn>\n<start_of_turn>model\n",
		"mistral": "<s>[INST] " + system + "\n\nHello [/INST] Hi</s>[INST] More [/INST] ",
	}
	for template: String in TEMPLATES:
		var actual: String = PROMPT.build(history, template)
		assert(actual == String(expected[template]), template + " serialization mismatch")


func test_continuation_keeps_last_assistant_open() -> void:
	var user_history: Array = [{"role": "user", "content": "Hello"}]
	var history: Array = user_history.duplicate(true)
	history.append({"role": "assistant", "content": "Partial\n  reply"})
	var closers: Dictionary = {
		"chatml": "<|im_end|>\n", "zephyr": "</s>\n",
		"llama3": "<|eot_id|>", "phi3": "<|end|>\n",
		"gemma": "<end_of_turn>\n", "mistral": "</s>",
	}
	for template: String in TEMPLATES:
		var prefix: String = PROMPT.build(user_history, template)
		var continued: String = PROMPT.build(history, template, true)
		assert(continued == prefix + "Partial\n  reply", template + " must resume without closing or duplicating assistant")
		var completed: String = PROMPT.build(history, template)
		assert(completed.begins_with(continued + String(closers[template])))
		assert(PROMPT.build(user_history, template, true) == prefix)


func test_empty_history_and_unknown_template() -> void:
	for template: String in TEMPLATES:
		var actual: String = PROMPT.build([], template)
		assert(actual.contains(CATALOG.SYSTEM_PROMPT))
		assert(PROMPT.build([], template, true) == actual)
	assert(PROMPT.build([], "unknown") == PROMPT.build([], "chatml"))
	assert(PROMPT.build([], " CHATML ") == PROMPT.build([], "chatml"))


func test_catalog_templates_are_covered() -> void:
	for entry: Dictionary in CATALOG.MODELS:
		assert(String(entry["template"]) in TEMPLATES)


func test_history_is_not_mutated_and_content_is_preserved() -> void:
	var history: Array = [
		{"role": "system", "content": "Additional instruction"},
		{"role": "user", "content": "  Keep\n\nspacing  "},
		{"role": "assistant", "content": ""},
	]
	var original: Array = history.duplicate(true)
	for template: String in TEMPLATES:
		var actual: String = PROMPT.build(history, template, true)
		assert(actual.contains("Additional instruction"))
		assert(actual.contains("  Keep\n\nspacing  "))
		assert(history == original)
