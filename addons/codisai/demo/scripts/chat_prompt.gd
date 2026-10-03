class_name CodisChatPrompt
extends RefCounted

## Serializes role/content dictionaries without modifying the supplied history.
## Continuing leaves a final assistant message open; otherwise a new assistant
## generation header is added. Unknown template names fall back to ChatML.
const CATALOG = preload("res://addons/codisai/demo/scripts/model_catalog.gd")


static func build(history: Array, template_name: String, continuing: bool = false) -> String:
	var template: String = template_name.strip_edges().to_lower()
	if template not in ["chatml", "zephyr", "llama3", "phi3", "gemma", "mistral"]:
		template = "chatml"
	var messages: Array[Dictionary] = []
	for item: Variant in history:
		if item is Dictionary:
			var role: String = String(item.get("role", "user"))
			if role in ["system", "user", "assistant"]:
				messages.append({"role": role, "content": String(item.get("content", ""))})
	var resume: bool = continuing and not messages.is_empty() and messages[-1]["role"] == "assistant"
	var prompt: String = ""
	var system_text: String = CATALOG.SYSTEM_PROMPT
	# These two formats have no system role: fold instructions into the first user.
	if template in ["gemma", "mistral"]:
		var turns: Array[Dictionary] = []
		for message: Dictionary in messages:
			if message["role"] == "system":
				system_text += "\n\n" + String(message["content"])
			else:
				turns.append(message.duplicate())
		var folded: bool = false
		for message: Dictionary in turns:
			if message["role"] == "user":
				message["content"] = system_text + "\n\n" + String(message["content"])
				folded = true
				break
		if not folded:
			turns.push_front({"role": "user", "content": system_text})
		prompt = "<bos>" if template == "gemma" else "<s>"
		for index: int in range(turns.size()):
			var message: Dictionary = turns[index]
			var content: String = String(message["content"])
			var open_reply: bool = resume and index == turns.size() - 1
			if template == "gemma":
				var role: String = "model" if message["role"] == "assistant" else "user"
				prompt += "<start_of_turn>%s\n%s" % [role, content]
				if not open_reply:
					prompt += "<end_of_turn>\n"
			elif message["role"] == "user":
				prompt += "[INST] %s [/INST]" % content
			else:
				prompt += " " + content
				if not open_reply:
					prompt += "</s>"
		if not resume:
			prompt += "<start_of_turn>model\n" if template == "gemma" else " "
		return prompt
	messages.push_front({"role": "system", "content": system_text})
	if template == "llama3":
		prompt = "<|begin_of_text|>"
	for index: int in range(messages.size()):
		var message: Dictionary = messages[index]
		prompt += _header(template, String(message["role"])) + String(message["content"])
		if not (resume and index == messages.size() - 1):
			prompt += _ending(template)
	if not resume:
		prompt += _header(template, "assistant")
	return prompt


static func _header(template: String, role: String) -> String:
	match template:
		"zephyr", "phi3":
			return "<|%s|>\n" % role
		"llama3":
			return "<|start_header_id|>%s<|end_header_id|>\n\n" % role
		_:
			return "<|im_start|>%s\n" % role


static func _ending(template: String) -> String:
	match template:
		"zephyr":
			return "</s>\n"
		"llama3":
			return "<|eot_id|>"
		"phi3":
			return "<|end|>\n"
		_:
			return "<|im_end|>\n"
