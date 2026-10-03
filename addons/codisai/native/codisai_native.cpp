#include "codisai_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <llama.h>

#include <algorithm>
#include <filesystem>
#include <mutex>
#include <string>
#include <system_error>
#include <vector>

namespace godot {
namespace {

std::once_flag backend_init_flag;

bool should_abort(void *user_data) {
	return static_cast<std::atomic<bool> *>(user_data)->load();
}

int dictionary_int(const Dictionary &values, const String &key, int fallback) {
	return static_cast<int>(values.get(key, fallback));
}

float dictionary_float(const Dictionary &values, const String &key, float fallback) {
	return static_cast<float>(values.get(key, fallback));
}

void fill_batch(llama_batch &batch, const std::vector<llama_token> &tokens, size_t start, size_t count,
		int position, bool mark_last) {
	batch.n_tokens = static_cast<int32_t>(count);
	for (size_t i = 0; i < count; ++i) {
		const size_t slot = i;
		batch.token[slot] = tokens[start + i];
		batch.pos[slot] = position + static_cast<int>(i);
		batch.n_seq_id[slot] = 1;
		batch.seq_id[slot][0] = 0;
		batch.logits[slot] = mark_last && i == count - 1 ? 1 : 0;
	}
}

String complete_utf8_prefix(std::string &pending, bool flush) {
	size_t complete = 0;
	while (complete < pending.size()) {
		const unsigned char lead = static_cast<unsigned char>(pending[complete]);
		size_t width = 1;
		if ((lead & 0xE0) == 0xC0) width = 2;
		else if ((lead & 0xF0) == 0xE0) width = 3;
		else if ((lead & 0xF8) == 0xF0) width = 4;
		if (complete + width > pending.size()) break;
		bool valid = true;
		for (size_t i = 1; i < width; ++i) {
			if ((static_cast<unsigned char>(pending[complete + i]) & 0xC0) != 0x80) {
				valid = false;
				break;
			}
		}
		complete += valid ? width : 1;
	}
	if (flush) complete = pending.size();
	if (complete == 0) return String();
	const String text = String::utf8(pending.data(), static_cast<int64_t>(complete));
	pending.erase(0, complete);
	return text;
}

} // namespace

void CodisAINative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_model", "path", "options"), &CodisAINative::load_model);
	ClassDB::bind_method(D_METHOD("unload_model"), &CodisAINative::unload_model);
	ClassDB::bind_method(D_METHOD("generate_async", "prompt", "options"), &CodisAINative::generate_async);
	ClassDB::bind_method(D_METHOD("cancel_generation"), &CodisAINative::cancel_generation);
	ClassDB::bind_method(D_METHOD("is_model_loaded"), &CodisAINative::is_model_loaded);
	ClassDB::bind_method(D_METHOD("is_generating"), &CodisAINative::is_generating);
	ClassDB::bind_method(D_METHOD("get_last_error"), &CodisAINative::get_last_error);
	ClassDB::bind_method(D_METHOD("get_model_info"), &CodisAINative::get_model_info);

	ADD_SIGNAL(MethodInfo("token_received", PropertyInfo(Variant::STRING, "text")));
	ADD_SIGNAL(MethodInfo("generation_finished",
		PropertyInfo(Variant::STRING, "text"), PropertyInfo(Variant::BOOL, "cancelled")));
	ADD_SIGNAL(MethodInfo("generation_failed", PropertyInfo(Variant::STRING, "message")));
}

CodisAINative::~CodisAINative() {
	cancel_generation();
	if (worker.joinable()) worker.join();
	unload_model();
}

void CodisAINative::_set_error(const String &message) {
	std::lock_guard<std::mutex> lock(state_mutex);
	last_error = message;
}

bool CodisAINative::load_model(const String &path, const Dictionary &options) {
	std::lock_guard<std::mutex> lifecycle_lock(lifecycle_mutex);
	if (generating.load()) {
		_set_error("Cannot load a model while generation is active.");
		return false;
	}
	if (worker.joinable()) worker.join();

	CharString path_utf8 = path.utf8();
	std::call_once(backend_init_flag, []() { llama_backend_init(); });

	llama_model_params model_params = llama_model_default_params();
	model_params.n_gpu_layers = std::max(0, dictionary_int(options, "gpu_layers", 0));
	llama_model *new_model = llama_load_model_from_file(path_utf8.get_data(), model_params);
	if (new_model == nullptr) {
		_set_error("llama.cpp could not load the GGUF model. Check the file and available memory.");
		return false;
	}

	llama_context_params context_params = llama_context_default_params();
	context_params.n_ctx = static_cast<uint32_t>(std::max(256, dictionary_int(options, "context_size", 2048)));
	const int requested_threads = dictionary_int(options, "threads", 0);
	context_params.n_threads = static_cast<uint32_t>(requested_threads > 0 ? requested_threads : std::max(1u, std::thread::hardware_concurrency()));
	context_params.n_threads_batch = context_params.n_threads;
	context_params.abort_callback = should_abort;
	context_params.abort_callback_data = &cancel_requested;
	llama_context *new_context = llama_new_context_with_model(new_model, context_params);
	if (new_context == nullptr) {
		llama_free_model(new_model);
		_set_error("llama.cpp could not create the inference context. Try a smaller context size.");
		return false;
	}

	std::lock_guard<std::mutex> lock(state_mutex);
	if (context != nullptr) llama_free(context);
	if (model != nullptr) llama_free_model(model);
	model = new_model;
	context = new_context;
	model_path = path;
	model_tensor_bytes = llama_model_size(model);
	std::error_code file_size_error;
	model_file_bytes = std::filesystem::file_size(std::filesystem::u8path(path_utf8.get_data()), file_size_error);
	if (file_size_error) model_file_bytes = 0;
	last_error = "";
	cancel_requested.store(false);
	return true;
}

void CodisAINative::unload_model() {
	std::lock_guard<std::mutex> lifecycle_lock(lifecycle_mutex);
	if (generating.load()) cancel_generation();
	if (worker.joinable()) worker.join();
	std::lock_guard<std::mutex> lock(state_mutex);
	if (context != nullptr) {
		llama_free(context);
		context = nullptr;
	}
	if (model != nullptr) {
		llama_free_model(model);
		model = nullptr;
	}
	model_path = "";
	model_file_bytes = 0;
	model_tensor_bytes = 0;
}

bool CodisAINative::generate_async(const String &prompt, const Dictionary &options) {
	std::lock_guard<std::mutex> lifecycle_lock(lifecycle_mutex);
	if (generating.load()) {
		_set_error("A generation is already running.");
		return false;
	}
	if (worker.joinable()) worker.join();
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		if (model == nullptr || context == nullptr) {
			generating.store(false);
			last_error = "No model is loaded.";
			return false;
		}
	}
	generating.store(true);
	cancel_requested.store(false);
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		last_error = "";
	}
	worker = std::thread(&CodisAINative::_run_generation, this, prompt, options);
	return true;
}

void CodisAINative::cancel_generation() {
	cancel_requested.store(true);
}

bool CodisAINative::is_model_loaded() const {
	std::lock_guard<std::mutex> lock(state_mutex);
	return model != nullptr && context != nullptr;
}

bool CodisAINative::is_generating() const {
	return generating.load();
}

String CodisAINative::get_last_error() const {
	std::lock_guard<std::mutex> lock(state_mutex);
	return last_error;
}

Dictionary CodisAINative::get_model_info() const {
	std::lock_guard<std::mutex> lock(state_mutex);
	Dictionary info;
	if (model == nullptr || context == nullptr) return info;
	char description[256] = {};
	llama_model_desc(model, description, sizeof(description));
	info["path"] = model_path;
	info["description"] = String::utf8(description);
	info["size_bytes"] = static_cast<int64_t>(model_file_bytes);
	info["tensor_bytes"] = static_cast<int64_t>(model_tensor_bytes);
	info["context_size"] = static_cast<int64_t>(llama_n_ctx(context));
	info["layers"] = static_cast<int64_t>(llama_n_layer(model));
	info["parameters"] = static_cast<int64_t>(llama_model_n_params(model));
	return info;
}

void CodisAINative::_run_generation(String prompt, Dictionary options) {
	llama_model *active_model = nullptr;
	llama_context *active_context = nullptr;
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		active_model = model;
		active_context = context;
	}

	String failure;
	String full_text;
	bool cancelled = false;
	const CharString prompt_utf8 = prompt.utf8();
	const int context_size = static_cast<int>(llama_n_ctx(active_context));
	const int max_tokens = std::max(1, dictionary_int(options, "max_tokens", 256));
	const float temperature = std::max(0.0f, dictionary_float(options, "temperature", 0.7f));
	const int top_k = std::max(1, dictionary_int(options, "top_k", 40));
	const float top_p = std::clamp(dictionary_float(options, "top_p", 0.95f), 0.01f, 1.0f);
	llama_kv_cache_clear(active_context);

	std::vector<llama_token> prompt_tokens(static_cast<size_t>(prompt_utf8.length()) + 8);
	int32_t token_count = llama_tokenize(active_model, prompt_utf8.get_data(), prompt_utf8.length(),
		prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()), true, true);
	if (token_count < 0) {
		prompt_tokens.resize(static_cast<size_t>(-token_count));
		token_count = llama_tokenize(active_model, prompt_utf8.get_data(), prompt_utf8.length(),
			prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()), true, true);
	}
	if (token_count <= 0) failure = "Prompt tokenization failed.";
	else prompt_tokens.resize(static_cast<size_t>(token_count));
	if (failure.is_empty() && static_cast<int>(prompt_tokens.size()) + max_tokens > context_size) {
		failure = "Prompt plus max_tokens exceeds the model context. Reduce the prompt or generation limit.";
	}

	llama_batch batch{};
	if (failure.is_empty()) {
		const size_t batch_capacity = static_cast<size_t>(std::min(context_size, 512));
		batch = llama_batch_init(static_cast<int32_t>(batch_capacity), 0, 1);
		if (batch.token == nullptr || batch.pos == nullptr || batch.n_seq_id == nullptr ||
				batch.seq_id == nullptr || batch.logits == nullptr) {
			failure = "llama.cpp could not allocate a prompt batch.";
		} else {
			for (size_t start = 0; start < prompt_tokens.size(); start += batch_capacity) {
				const size_t count = std::min(batch_capacity, prompt_tokens.size() - start);
				fill_batch(batch, prompt_tokens, start, count, static_cast<int>(start), start + count == prompt_tokens.size());
				if (llama_decode(active_context, batch) != 0) {
					if (!cancel_requested.load()) failure = "llama.cpp failed while evaluating the prompt.";
					break;
				}
				if (cancel_requested.load()) break;
			}
		}
	}

	std::string pending_utf8;
	std::vector<llama_token> history = prompt_tokens;
	for (int generated = 0; failure.is_empty() && generated < max_tokens && !cancel_requested.load(); ++generated) {
		float *logits = llama_get_logits_ith(active_context, -1);
		if (logits == nullptr) {
			failure = "llama.cpp did not return token logits.";
			break;
		}
		const int vocab_size = llama_n_vocab(active_model);
		std::vector<llama_token_data> candidates;
		candidates.reserve(static_cast<size_t>(vocab_size));
		for (llama_token token_id = 0; token_id < vocab_size; ++token_id) {
			candidates.push_back({token_id, logits[token_id], 0.0f});
		}
		llama_token_data_array candidate_array{candidates.data(), candidates.size(), false};
		llama_token next_token;
		if (temperature <= 0.0f) {
			next_token = llama_sample_token_greedy(active_context, &candidate_array);
		} else {
			llama_sample_top_k(active_context, &candidate_array, top_k, 1);
			llama_sample_top_p(active_context, &candidate_array, top_p, 1);
			llama_sample_temp(active_context, &candidate_array, temperature);
			llama_sample_softmax(active_context, &candidate_array);
			next_token = llama_sample_token(active_context, &candidate_array);
		}
		if (llama_token_is_eog(active_model, next_token)) break;

		history.push_back(next_token);
		char piece_buffer[256];
		int32_t piece_size = llama_token_to_piece(active_model, next_token, piece_buffer, sizeof(piece_buffer), 0, false);
		if (piece_size < 0) {
			std::vector<char> larger_piece(static_cast<size_t>(-piece_size));
			piece_size = llama_token_to_piece(active_model, next_token, larger_piece.data(),
				static_cast<int32_t>(larger_piece.size()), 0, false);
			if (piece_size > 0) pending_utf8.append(larger_piece.data(), static_cast<size_t>(piece_size));
		} else if (piece_size > 0) {
			pending_utf8.append(piece_buffer, static_cast<size_t>(piece_size));
		}
		String safe_piece = complete_utf8_prefix(pending_utf8, false);
		if (!safe_piece.is_empty()) {
			full_text += safe_piece;
			call_deferred("emit_signal", StringName("token_received"), safe_piece);
		}

		batch.n_tokens = 1;
		batch.token[0] = next_token;
		batch.pos[0] = static_cast<llama_pos>(history.size() - 1);
		batch.n_seq_id[0] = 1;
		batch.seq_id[0][0] = 0;
		batch.logits[0] = 1;
		if (llama_decode(active_context, batch) != 0 && !cancel_requested.load()) {
			failure = "llama.cpp failed while decoding generated text.";
			break;
		}
	}
	if (batch.token != nullptr) llama_batch_free(batch);
	cancelled = cancel_requested.load();
	String remainder = complete_utf8_prefix(pending_utf8, true);
	if (!remainder.is_empty()) {
		full_text += remainder;
		call_deferred("emit_signal", StringName("token_received"), remainder);
	}

	if (!failure.is_empty()) {
		_set_error(failure);
		call_deferred("emit_signal", StringName("generation_failed"), failure);
	} else {
		call_deferred("emit_signal", StringName("generation_finished"), full_text, cancelled);
	}
	generating.store(false);
}

} // namespace godot
