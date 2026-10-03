class_name TestCodisModelStorage
extends Node

func test_platform_model_directories() -> void:
	for platform: String in ["Windows", "Linux", "Android"]:
		assert(ModelCatalog.models_dir_for_platform(platform).ends_with("CodisGames/CodisAI/models"))


func test_default_models_directory_is_created() -> void:
	var model_dir: String = ModelCatalog.ensure_models_dir()
	assert(model_dir == "user://models" or model_dir.is_absolute_path())
	assert(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(model_dir)))
