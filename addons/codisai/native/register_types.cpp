#include "codisai_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_codisai(ModuleInitializationLevel level) {
	if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		ClassDB::register_class<CodisAINative>();
	}
}

void uninitialize_codisai(ModuleInitializationLevel level) {
	if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		// CodisAINative instances release their model/context in their destructor.
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT codisai_library_init(
		GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library,
		GDExtensionInitialization *initialization) {
		GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
		init_obj.register_initializer(initialize_codisai);
		init_obj.register_terminator(uninitialize_codisai);
		init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
		return init_obj.init();
}
}
