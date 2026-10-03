# CodisAI

**Run local GGUF language models inside Godot.** CodisAI is an open-source Godot Engine GDExtension and chat demo that lets Godot projects load GGUF models and generate text on-device through a GDScript API. Its native inference backend is powered by [llama.cpp](https://github.com/ggerganov/llama.cpp).

CodisAI is for developers exploring private, offline-capable AI features in games and interactive applications. Prompt inference runs locally—there is no hosted inference service or API key. Internet access is only needed for optional model downloads and the first native build's dependency fetches.

> **Status:** This repository targets Godot 4.7 and includes native source, CMake configuration, CI build workflows, a GDScript facade, and a complete chat demo. The extension manifest maps Windows x86_64, Linux x86_64/arm64, macOS x86_64/arm64, and Android arm64/arm32/x86_64/x86. Some prebuilt binaries are included (currently Windows Release x86_64, Linux Release x86_64/arm64, and Android Debug/Release for all four mapped ABIs); other platform/configuration combinations must be built. Android and other non-desktop exports need validation on the target device; iOS and WebAssembly are not implemented. Model weights are not included.

## Features

- **Local model inference:** Load and release GGUF models with the llama.cpp backend. CPU inference is the baseline; GPU offload depends on a separately configured and packaged llama.cpp backend.
- **Streaming generation:** Generate text on a worker thread, receive progressive `token_received` signals, and request cancellation.
- **Generation controls:** Configure context length, CPU threads, GPU layers, temperature, top-k, top-p, and maximum output tokens.
- **Model information:** Read model description, parameter and layer counts, context size, on-disk file size, and tensor storage size.
- **Chat application demo:** A responsive chat interface with streamed assistant replies, selectable response text, code-block rendering, and prompt templates for supported model families.
- **Model discovery and downloads:** Browse curated Hugging Face GGUF models, review their specifications, download a selected file, and load it in the demo.
- **Local conversation library:** Save conversations as individual JSON files; reopen or remove saved chats from the Recent window.
- **Customizable interface:** Configure generation settings, UI scale, and Dark, AMOLED, or Light appearance. Attach supported text files to prompts.

Models are not bundled. Add your own `.gguf` files or download one from the demo's model library. The demo stores models, settings, and recent chats in the OS Documents directory under `CodisGames/CodisAI` (`models/`, `settings.cfg`, and `recent/`). It attempts to migrate the older `CodisGames/Codisai` folder when safe. Documents access varies by operating system; Android shared-storage behavior depends on the device and OS version. Always review model and backend licenses before redistribution.

## Requirements

### Running the project

- Godot **4.7 or newer** (the project declares Godot 4.7 features).
- A compiled native library matching the operating system, CPU architecture, and Debug/Release export configuration.
- A local `.gguf` model and enough memory for that model and its configured context. No weights are bundled.

### Building the native library

- CMake **3.22 or newer**, a C/C++ toolchain, Git, and Python 3 for the `godot-cpp` binding generator.
- Network access on the first CMake configure to fetch the pinned native dependencies.
- For Android, an Android NDK compatible with the build host. A Windows NDK is not a Linux-hosted NDK and cannot be used by Linux tools in WSL.

## Build the native extension

Run commands from the repository root. CMake fetches `godot-cpp` (`godot-4.5-stable`) and llama.cpp (`b3450`), then writes the library into `addons/codisai/bin/<platform>/`. Use a separate build directory for each platform and configuration. Match Debug/Release libraries to your Godot export template.

For a Release build on the current host:

```sh
cmake -S addons/codisai/native -B build/codisai-release -DCMAKE_BUILD_TYPE=Release
cmake --build build/codisai-release --config Release --parallel
```

For Debug, use a separate directory and set `-DCMAKE_BUILD_TYPE=Debug`. With Visual Studio or another multi-configuration generator, select the configuration using `--config Debug` or `--config Release`. These are host builds; cross-compiling requires a suitable CMake toolchain.

The extension manifest is [addons/codisai/native/codisai.gdextension](addons/codisai/native/codisai.gdextension). It maps Windows x86_64, Linux x86_64/arm64, macOS x86_64/arm64, and Android arm64/arm32/x86_64/x86. Editor entries use the Release library.

### GitHub Actions artifacts

The workflow at [.github/workflows/build-native.yml](.github/workflows/build-native.yml) builds the mapped targets in Debug and Release and packages the addon as a downloadable artifact. It can be started from **Actions → Build CodisAI GDExtension → Run workflow**; configured push and pull-request path filters also trigger it. The separate [.github/workflows/build-macos.yml](.github/workflows/build-macos.yml) workflow builds macOS x86_64 and arm64 in both configurations and packages a macOS addon artifact.

### Android and WSL/Linux

The CMake configuration disables OpenMP for Android to avoid a separate `libomp.so` dependency. The CI workflow shows the NDK, Android ABI and static C++ runtime options. The helper [`build_wsl.sh`](addons/codisai/native/build_wsl.sh) can build Linux x86_64 Release and Android Debug/Release libraries for arm64-v8a, armeabi-v7a, x86_64, and x86 from Ubuntu WSL/Linux. It expects a Linux-hosted NDK at `$HOME/Android/android-ndk-r28c` by default, or the location in `ANDROID_NDK_ROOT`; its default Android minimum API is 26.

After updating Android libraries, export a new APK: an APK already built contains its previous native binaries. Android packaging, storage permissions, Documents access, model downloads, and inference still need to be verified on a device or emulator. iOS libraries are not implemented; Windows and WSL are not substitutes for the required Apple toolchain.

### GPU support

CPU inference is the default baseline. GPU offload is not enabled by this CMake configuration. To use a llama.cpp GPU backend, configure a supported GGML backend and validate all native dependencies and export packaging on the target system.

## Run the chat demo

1. Check whether a matching native library is already included for your editor platform, architecture, and configuration; if not, build it. Its filename must match the extension manifest.
2. Open the project in Godot 4.7 or later. The CodisAI editor plugin adds **CodisAI: Open Local Chat Demo** to the Tools menu; the project main scene is `addons/codisai/demo/scenes/chat.tscn`.
3. Load a local `.gguf` model or download one from the Model library. No model is included.
4. Enter a prompt and send it. Inference runs locally; the send/stop control requests cancellation.

## Chat demo

- **Local models:** Browse `.gguf` files in the models folder, select a file to load, and view model/runtime information. Only one model is loaded at a time.
- **Model library:** Browse curated Hugging Face model entries, see specifications, resolve the model file through the Hugging Face API, and download it to the models folder. A failed download can be retried from the beginning.
- **Chat and prompt formatting:** View user and assistant messages, stream generated text, select response text, and render fenced code blocks with a code-copy control. The demo applies supported ChatML, Llama 3, Zephyr, Phi-3, Gemma, and Mistral prompt formats according to its catalog entry.
- **Text attachments:** Attach `.txt`, `.md`, `.csv`, `.json`, `.xml`, or `.log` files up to 1 MiB; their text is appended to the next prompt.
- **Recent conversations:** The Recent popup lists each saved chat's prompt, model, and modified date. Select a prompt to restore its transcript, or remove its JSON record.
- **Settings and appearance:** Change context size, output token limit, temperature, CPU thread count, UI scale, and Dark, AMOLED, or Light theme. Preferences persist locally.

### Local data locations

Models, settings, and recent chats are stored under the operating system's Documents directory:

| Data | Path below Documents |
| --- | --- |
| Downloaded models | `CodisGames/CodisAI/models/` |
| Settings | `CodisGames/CodisAI/settings.cfg` |
| Recent conversations | `CodisGames/CodisAI/recent/*.json` |

The demo creates required directories and attempts to migrate the older `CodisGames/Codisai` folder when safe. Documents-folder access can differ between platforms; Android shared-storage access depends on Android version and device policy.

## GDScript API

```gdscript
extends Node

var ai: CodisAI
var response_text: String = ""

func _ready() -> void:
	ai = CodisAI.new()
	ai.token_received.connect(_on_token_received)
	ai.generation_finished.connect(_on_generation_finished)
	ai.generation_failed.connect(_on_generation_failed)
	ai.error_occurred.connect(_on_error)

	var options: Dictionary = {
		"context_size": 4096,
		"threads": 0,       # 0 uses the available CPU thread count
		"gpu_layers": 0,    # CPU baseline
		"max_tokens": 256,
		"temperature": 0.7,
		"top_k": 40,
		"top_p": 0.95,
	}
	if ai.load_model("user://models/assistant.gguf", options):
		response_text = ""
		ai.generate_async("Explain how Godot nodes work.", options)

func _on_token_received(piece: String) -> void:
	response_text += piece

func _on_generation_finished(_text: String, cancelled: bool) -> void:
	print("Generation finished. Cancelled: ", cancelled)

func _on_generation_failed(message: String) -> void:
	push_error(message)

func _on_error(message: String) -> void:
	push_warning(message)
```

`CodisAI` extends `RefCounted`; keep a reference for as long as it is needed. `load_model()` is synchronous and may pause the calling thread while loading a large model. `generate_async()` runs inference on a worker thread. Connect to the signals before generation: text is emitted through `token_received`, successful or cancelled completion through `generation_finished`, and inference failures through `generation_failed`. Invalid requests and facade/runtime errors are reported through `error_occurred`. Call `cancel_generation()` to request cancellation. Avoid replacing or unloading a model while generation is active.

The API passes the prompt string as-is; it does not automatically construct a chat template from the GGUF metadata. Applications should format their prompt for the chosen model. The demo's prompt builder applies its supported template formats and resubmits conversation history on each turn.

## API reference

### `CodisAI`

| Method | Purpose |
| --- | --- |
| `load_model(path: String, options: Dictionary = {}) -> bool` | Load a local GGUF model. |
| `unload_model() -> void` | Release the model and inference context. |
| `generate_async(prompt: String, options: Dictionary = {}) -> bool` | Start asynchronous text generation. |
| `cancel_generation() -> void` | Request cancellation of active generation. |
| `is_model_loaded() -> bool` | Check whether a model is loaded. |
| `is_generating() -> bool` | Check whether generation is active. |
| `get_model_info() -> Dictionary` | Read metadata for the loaded model. |
| `get_model_path() -> String` | Get the current model path. |
| `get_last_error() -> String` | Get the facade's last error. |
| `is_runtime_available() -> bool` | Static check for the native runtime. |

Options default to `context_size=2048`, `threads=0`, `gpu_layers=0`, `temperature=0.7`, `top_k=40`, `top_p=0.95`, and `max_tokens=256`. `context_size`, `threads`, and `gpu_layers` are used while creating the model context; sampling settings and `max_tokens` are used for generation.

Signals: `model_loaded(model_info: Dictionary)`, `model_unloaded`, `token_received(text: String)`, `generation_finished(text: String, cancelled: bool)`, `generation_failed(message: String)`, and `error_occurred(message: String)`.

`get_model_info()` includes `path`, `description`, `size_bytes` (GGUF file size on disk), `tensor_bytes` (tensor storage size reported by llama.cpp), `context_size`, `layers`, and `parameters`. The file and tensor sizes measure different things and can differ.

## Repository layout

```text
addons/codisai/
├── native/        C++ GDExtension, manifest, and CMake build configuration
├── runtime/       Public GDScript facade
├── demo/
│   ├── scenes/    Chat demo scenes
│   └── scripts/   Chat UI, model catalog/downloader, prompt and recent storage
└── bin/           Native libraries generated by platform builds

tests/              GDScript tests for rendering, model storage, runtime, prompts, UI and recent chats
.github/workflows/  Native build and packaging workflows
```

## Limitations and safety

- A manifest mapping does not mean a target has been built or device-tested. A matching native library and Godot export template are needed for each platform, architecture, and configuration. Android device behavior and Linux/macOS target behavior should be verified on their intended systems. iOS and WebAssembly are not implemented.
- Android model downloads require network access and suitable export permissions. Android shared Documents storage access can vary by OS version and device policy.
- Model loading is synchronous. Generation is one request at a time per `CodisAI` instance. The native backend clears the llama.cpp KV cache between generations, so a chat application needs to include conversation context in each prompt; the demo rebuilds and evaluates it each turn.
- GPU offload requires an explicitly configured supported GGML backend and correctly packaged dependencies. `gpu_layers=0` is the CPU baseline.
- Model and context memory requirements can be substantial. Choose settings appropriate to the target device and only load model files from sources you trust.
- GGUF support does not guarantee every architecture, multimodal model, or chat template is supported by the pinned llama.cpp version. Model catalog entries are curated and upstream availability or descriptions can change.
- Review third-party model licenses and terms before use or redistribution. CodisAI does not bundle model weights.

## Testing

GDScript tests are located under [`tests/`](tests/). They cover chat/code rendering, model storage, native runtime registration, prompt templates, recent-conversation persistence, and response UI behavior. Automated tests do not replace native compilation, export checks, or testing on each target platform.

## License

CodisAI source code is licensed under the [MIT License](LICENSE). llama.cpp, `godot-cpp`, and downloaded model weights have their own licenses and terms. The CodisAI license does not grant rights to third-party model weights.
