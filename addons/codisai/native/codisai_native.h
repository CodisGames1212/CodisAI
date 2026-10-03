#ifndef CODISAI_NATIVE_H
#define CODISAI_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <atomic>
#include <mutex>
#include <thread>

struct llama_context;
struct llama_model;

namespace godot {

class CodisAINative : public RefCounted {
	GDCLASS(CodisAINative, RefCounted)

	llama_model *model = nullptr;
	llama_context *context = nullptr;
	std::thread worker;
	std::mutex lifecycle_mutex;
	mutable std::mutex state_mutex;
	std::atomic<bool> generating = false;
	std::atomic<bool> cancel_requested = false;
	String last_error;
	String model_path;
	uint64_t model_file_bytes = 0;
	uint64_t model_tensor_bytes = 0;

	static void _bind_methods();
	void _run_generation(String prompt, Dictionary options);
	void _set_error(const String &message);

public:
	CodisAINative() = default;
	~CodisAINative();

	bool load_model(const String &path, const Dictionary &options);
	void unload_model();
	bool generate_async(const String &prompt, const Dictionary &options);
	void cancel_generation();
	bool is_model_loaded() const;
	bool is_generating() const;
	String get_last_error() const;
	Dictionary get_model_info() const;
};

} // namespace godot

#endif
