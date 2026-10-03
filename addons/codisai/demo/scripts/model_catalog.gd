class_name ModelCatalog
extends RefCounted

## Curated catalog of GGUF chat models that can be downloaded from Hugging Face,
## plus helpers for scanning locally installed models.
##
## Each entry describes a model's specification (parameter count, quantisation,
## context length, licence) and the chat template it expects. The downloader
## resolves the exact GGUF filename through the Hugging Face API, so `file` is
## only a best-guess used for display and offline reference.

const DOCUMENTS_SUBPATH := "CodisGames/CodisAI/models"
const STORAGE = preload("res://addons/codisai/demo/scripts/recent_store.gd")

const SYSTEM_PROMPT := "You are CodisAI, a concise, friendly AI assistant running locally inside the Godot engine. Answer clearly and helpfully."

# `match` is a lowercase substring used to recognise an already-installed model
# file on disk. `template` selects the prompt wrapper used in chatbox.gd.
const MODELS := [
	{
		"name": "Qwen2.5 0.5B Instruct",
		"repo": "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
		"file": "qwen2.5-0.5b-instruct-q4_k_m.gguf",
		"match": "qwen2.5-0.5b",
		"quant": "Q4_K_M",
		"params": "0.5B",
		"context": 32768,
		"size_mb": 491,
		"license": "Apache-2.0",
		"template": "chatml",
		"description": "Tiny, fast Qwen2.5 instruct model. Great starter model for low-end machines and quick replies.",
	},
	{
		"name": "Qwen2.5 1.5B Instruct",
		"repo": "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
		"file": "qwen2.5-1.5b-instruct-q4_k_m.gguf",
		"match": "qwen2.5-1.5b",
		"quant": "Q4_K_M",
		"params": "1.5B",
		"context": 32768,
		"size_mb": 1120,
		"license": "Apache-2.0",
		"template": "chatml",
		"description": "Balanced small model with strong reasoning for its size. A good default for desktop chat.",
	},
	{
		"name": "Qwen2.5 3B Instruct",
		"repo": "Qwen/Qwen2.5-3B-Instruct-GGUF",
		"file": "qwen2.5-3b-instruct-q4_k_m.gguf",
		"match": "qwen2.5-3b",
		"quant": "Q4_K_M",
		"params": "3B",
		"context": 32768,
		"size_mb": 2100,
		"license": "Qwen Research",
		"template": "chatml",
		"description": "Higher-quality Qwen2.5 variant. Needs more RAM but produces noticeably better answers.",
	},
	{
		"name": "SmolLM2 360M Instruct",
		"repo": "HuggingFaceTB/SmolLM2-360M-Instruct-GGUF",
		"file": "smollm2-360m-instruct-q8_0.gguf",
		"match": "smollm2-360m",
		"quant": "Q8_0",
		"params": "360M",
		"context": 8192,
		"size_mb": 386,
		"license": "Apache-2.0",
		"template": "chatml",
		"description": "Ultra-light instruct model. Runs on almost anything, suited to quick prototyping.",
	},
	{
		"name": "SmolLM2 1.7B Instruct",
		"repo": "HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF",
		"file": "smollm2-1.7b-instruct-q4_k_m.gguf",
		"match": "smollm2-1.7b",
		"quant": "Q4_K_M",
		"params": "1.7B",
		"context": 8192,
		"size_mb": 1050,
		"license": "Apache-2.0",
		"template": "chatml",
		"description": "Compact modern instruct model with good instruction following at a small size.",
	},
	{
		"name": "TinyLlama 1.1B Chat",
		"repo": "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
		"file": "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
		"match": "tinyllama-1.1b",
		"quant": "Q4_K_M",
		"params": "1.1B",
		"context": 2048,
		"size_mb": 669,
		"license": "Apache-2.0",
		"template": "zephyr",
		"description": "Well-known compact chat model. Fast CPU inference with modest memory use.",
	},
	{
		"name": "Llama 3.2 1B Instruct",
		"repo": "bartowski/Llama-3.2-1B-Instruct-GGUF",
		"file": "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
		"match": "llama-3.2-1b",
		"quant": "Q4_K_M",
		"params": "1B",
		"context": 131072,
		"size_mb": 808,
		"license": "Llama 3.2 Community",
		"template": "llama3",
		"description": "Meta's small Llama 3.2 instruct model. Long context and solid general chat ability.",
	},
	{
		"name": "Llama 3.2 3B Instruct",
		"repo": "bartowski/Llama-3.2-3B-Instruct-GGUF",
		"file": "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
		"match": "llama-3.2-3b",
		"quant": "Q4_K_M",
		"params": "3B",
		"context": 131072,
		"size_mb": 2020,
		"license": "Llama 3.2 Community",
		"template": "llama3",
		"description": "Larger Llama 3.2 instruct model. Stronger reasoning, needs more memory.",
	},
	{
		"name": "Phi-3 Mini 4K Instruct",
		"repo": "microsoft/Phi-3-mini-4k-instruct-gguf",
		"file": "Phi-3-mini-4k-instruct-q4.gguf",
		"match": "phi-3-mini",
		"quant": "Q4",
		"params": "3.8B",
		"context": 4096,
		"size_mb": 2400,
		"license": "MIT",
		"template": "phi3",
		"description": "Microsoft Phi-3 Mini instruct. Strong reasoning for its size with a permissive licence.",
	},
	{
		"name": "Gemma 2 2B IT",
		"repo": "bartowski/gemma-2-2b-it-GGUF",
		"file": "gemma-2-2b-it-Q4_K_M.gguf",
		"match": "gemma-2-2b",
		"quant": "Q4_K_M",
		"params": "2B",
		"context": 8192,
		"size_mb": 1710,
		"license": "Gemma",
		"template": "gemma",
		"description": "Google Gemma 2 2B instruction-tuned model. Friendly, coherent conversational replies.",
	},
	{
		"name": "Mistral 7B Instruct v0.2",
		"repo": "TheBloke/Mistral-7B-Instruct-v0.2-GGUF",
		"file": "mistral-7b-instruct-v0.2.Q4_K_M.gguf",
		"match": "mistral-7b-instruct",
		"quant": "Q4_K_M",
		"params": "7B",
		"context": 32768,
		"size_mb": 4370,
		"license": "Apache-2.0",
		"template": "mistral",
		"description": "Widely used 7B instruct model. High quality; recommended only for machines with ample RAM.",
	},
]


## Uses the same Documents/CodisGames/CodisAI/models location on every platform.
static func default_models_dir() -> String:
	return models_dir_for_platform(OS.get_name())


## Resolve the shared Documents model location for each target platform.
static func models_dir_for_platform(_platform_name: String) -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join(DOCUMENTS_SUBPATH)


## Ensures the models directory exists and returns it.
static func ensure_models_dir() -> String:
	STORAGE.ensure_root()
	var dir: String = default_models_dir()
	if dir.begins_with("user://"):
		var relative_path: String = dir.trim_prefix("user://")
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
			var user_dir: DirAccess = DirAccess.open("user://")
			if user_dir != null:
				user_dir.make_dir_recursive(relative_path)
	else:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
	return dir


## Lists every .gguf file in `dir_path` as {file, path, size_bytes} dictionaries.
static func scan_local(dir_path: String) -> Array:
	var found: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".gguf"):
			var full: String = dir_path.path_join(name)
			found.append({
				"file": name,
				"path": full,
				"size_bytes": _file_size(full),
			})
		name = dir.get_next()
	dir.list_dir_end()
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["file"]).naturalnocasecmp_to(String(b["file"])) < 0)
	return found


## Returns the catalog entry that matches a local file name, or {} if unknown.
static func find_by_filename(file_name: String) -> Dictionary:
	var lower := file_name.to_lower()
	for entry in MODELS:
		if lower.find(String(entry["match"])) != -1:
			return entry
	return {}


## Returns the local path of an installed copy of `entry`, or "" if absent.
static func installed_path(entry: Dictionary, local_files: Array) -> String:
	var token := String(entry["match"])
	for item in local_files:
		if String(item["file"]).to_lower().find(token) != -1:
			return String(item["path"])
	return ""


## Direct Hugging Face download URL for a repo + filename.
static func download_url(repo: String, file_name: String) -> String:
	return "https://huggingface.co/%s/resolve/main/%s?download=true" % [repo, file_name]


## Hugging Face API endpoint that lists a repo's files.
static func api_url(repo: String) -> String:
	return "https://huggingface.co/api/models/%s" % repo


## Formats a byte count into a readable string.
static func format_bytes(byte_count: int) -> String:
	const KIB := 1024.0
	const MIB := 1024.0 * 1024.0
	const GIB := 1024.0 * 1024.0 * 1024.0
	var value := float(byte_count)
	if value >= GIB:
		return "%.2f GB" % (value / GIB)
	if value >= MIB:
		return "%.0f MB" % (value / MIB)
	if value >= KIB:
		return "%.0f KB" % (value / KIB)
	return "%d B" % byte_count


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size
