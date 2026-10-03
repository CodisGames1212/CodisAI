class_name CodisRecentStore
extends RefCounted

static func root_dir() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("CodisGames/CodisAI")

static func ensure_root() -> String:
	var root: String = root_dir()
	var parent: String = root.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	# Inspect real directory casing (Windows treats both spellings as the same path).
	var directory: DirAccess = DirAccess.open(parent)
	if directory != null:
		for name: String in directory.get_directories():
			if name == "Codisai":
				var old: String = parent.path_join(name)
				if OS.get_name() == "Windows":
					var temporary: String = parent.path_join("CodisAI_case_migration")
					if not DirAccess.dir_exists_absolute(temporary) and DirAccess.rename_absolute(old, temporary) == OK:
						if DirAccess.rename_absolute(temporary, root) != OK:
							DirAccess.rename_absolute(temporary, old)
				elif not DirAccess.dir_exists_absolute(root):
					DirAccess.rename_absolute(old, root)
	DirAccess.make_dir_recursive_absolute(root)
	return root

static func save_record(directory: String, id: String, record: Dictionary) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var file: FileAccess = FileAccess.open(directory.path_join(id + ".json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(record, "\t"))
	file.flush()
	return file.get_error()

static func records(directory: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return result
	for filename: String in folder.get_files():
		if not filename.ends_with(".json"):
			continue
		var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary and data.get("history") is Array:
			data["id"] = filename.get_basename()
			result.append(data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("modified", 0)) > float(b.get("modified", 0)))
	return result

static func remove_record(directory: String, id: String) -> Error:
	if id != id.get_file() or id.is_empty():
		return ERR_INVALID_PARAMETER
	return DirAccess.remove_absolute(directory.path_join(id + ".json"))
