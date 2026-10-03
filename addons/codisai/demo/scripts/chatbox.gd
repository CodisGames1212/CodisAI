class_name CodisAIChatbox
extends Control

const CLIENT = preload("res://addons/codisai/runtime/codisai_client.gd")
const CATALOG = preload("res://addons/codisai/demo/scripts/model_catalog.gd")
const CODE = preload("res://addons/codisai/demo/scripts/code_block.gd")
const PROMPT = preload("res://addons/codisai/demo/scripts/chat_prompt.gd")
const TOUCH_COPY = preload("res://addons/codisai/demo/scripts/response_touch_copy.gd")
const AVATAR = preload("res://addons/codisai/demo/assets/assistant_avatar.png")
const SIDEBAR_ICON = preload("res://addons/codisai/demo/assets/sidebar.png")
const SEND_ICON = preload("res://addons/codisai/demo/assets/send_promp.png")
const NEW_CHAT_ICON = preload("res://addons/codisai/demo/assets/new_chat.png")
const RECENT_ICON = preload("res://addons/codisai/demo/assets/recent.png")
const SETTINGS_ICON = preload("res://addons/codisai/demo/assets/settings.png")
const MORE_ICON = preload("res://addons/codisai/demo/assets/more.png")

var client: CLIENT
var _preferences: ConfigFile = ConfigFile.new()
var _settings_path: String
var _models_dir: String
var _theme_name: String = "Dark"
var _ui_scale: float = 1.0
var _split: HSplitContainer
var _sidebar: PanelContainer
var _sidebar_button: Button
var _sidebar_icon: TextureRect
var _sidebar_rotation_tween: Tween
var _background: ColorRect
var _chat_scroll: ScrollContainer
var _chat_list: VBoxContainer
var _library_list: VBoxContainer
var _prompt_input: TextEdit
var _send_button: Button
var _attachment_button: Button
var _status_label: Label
var _model_label: Label
var _settings_window: Window
var _generation_inputs: Dictionary = {}
var _history: Array[Dictionary] = []
var _messages: Array[Dictionary] = []
var _active_response: Dictionary = {}
var _current_text: String = ""
var _current_entry: Dictionary = {}
var _loading: bool = false
var _attached_documents: Array[Dictionary] = []
var _attachment_label: Label
var _model_picker: FileDialog
var _document_picker: FileDialog
var _meta_request: HTTPRequest
var _download_request: HTTPRequest
var _pending_entry: Dictionary = {}
var _pending_path: String = ""
var _downloading: bool = false
var _download_failed: bool = false
var _dl_label: Label
var _dl_bar: ProgressBar
var _retry_button: Button
var _last_split_offset: int = 0
const RECENT = preload("res://addons/codisai/demo/scripts/recent_store.gd")
var _recent_window: Window
var _recent_grid: GridContainer
var _recent_dir: String
var _recent_id: String = ""

func _build_recent() -> void:
	_recent_window = Window.new()
	_recent_window.name = "RecentWindow"
	_recent_window.title = "Recent conversations"
	_recent_window.size = Vector2i(760, 440)
	_recent_window.visible = false
	_recent_window.close_requested.connect(_recent_window.hide)
	add_child(_recent_window)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recent_window.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_recent_grid = GridContainer.new()
	_recent_grid.columns = 4
	_recent_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recent_grid.add_theme_constant_override("h_separation", 12)
	_recent_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_recent_grid)

func _show_recent() -> void:
	_refresh_recent()
	_recent_window.popup_centered()

func _refresh_recent() -> void:
	for child: Node in _recent_grid.get_children():
		_recent_grid.remove_child(child)
		child.queue_free()
	for title: String in ["Prompt", "Model", "Modified", ""]:
		var heading: Label = _label(_recent_grid, title)
		heading.autowrap_mode = TextServer.AUTOWRAP_OFF
		if title == "Prompt":
			heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif title == "Model":
			heading.custom_minimum_size.x = 180
		elif title == "Modified":
			heading.custom_minimum_size.x = 90
		else:
			heading.custom_minimum_size.x = 36
	for record: Dictionary in RECENT.records(_recent_dir):
		var title: String = String(record.get("prompt", "Conversation")).replace("\n", " ")
		var open: Button = _button(_recent_grid, title.left(28) + ("…" if title.length() > 28 else ""), _open_recent.bind(record))
		open.tooltip_text = title
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var model: Label = _label(_recent_grid, String(record.get("model", "Unknown")))
		model.custom_minimum_size.x = 180
		model.autowrap_mode = TextServer.AUTOWRAP_OFF
		model.clip_text = true
		model.tooltip_text = model.text
		_label(_recent_grid, String(record.get("date", "")))
		var remove: Button = _button(_recent_grid, "X", _remove_recent.bind(String(record["id"])))
		remove.tooltip_text = "Remove saved conversation"
	_set_mouse_policy(_recent_window)

func _save_recent() -> void:
	if _history.is_empty():
		return
	if _recent_id.is_empty():
		_recent_id = "%d_%d" % [int(Time.get_unix_time_from_system() * 1000000), randi()]
	var date: Dictionary = Time.get_date_dict_from_system()
	var transcript: Array[Dictionary] = []
	for message: Dictionary in _messages:
		transcript.append({"role": message["role"], "text": message["text"]})
	var record: Dictionary = {"version": 1, "prompt": _history[0]["content"], "model": _model_label.text, "modified": Time.get_unix_time_from_system(), "date": "%d/%d/%02d" % [date["month"], date["day"], int(date["year"]) % 100], "history": _history, "messages": transcript}
	var error: Error = RECENT.save_record(_recent_dir, _recent_id, record)
	if error != OK:
		_set_status("Recent save failed: " + error_string(error))

func _remove_recent(id: String) -> void:
	var error: Error = RECENT.remove_record(_recent_dir, id)
	if error != OK:
		_set_status("Recent removal failed: " + error_string(error))
	else:
		if _recent_id == id:
			_recent_id = ""
		_refresh_recent()

func _open_recent(record: Dictionary) -> void:
	if client.is_generating() or _loading:
		_set_status("Stop generation before opening a recent conversation.")
		return
	for child: Node in _chat_list.get_children():
		_chat_list.remove_child(child)
		child.queue_free()
	_messages.clear()
	_history.clear()
	for entry: Variant in record.get("history", []):
		if entry is Dictionary and entry.has("role") and entry.has("content"):
			_history.append(entry)
	for message: Variant in record.get("messages", []):
		if message is Dictionary and message.has("role") and message.has("text"):
			_add_message(String(message["role"]), String(message["text"]))
	_recent_id = String(record["id"])
	_attached_documents.clear()
	_attachment_label.visible = false
	_prompt_input.clear()
	_recent_window.hide()
	_set_status("Conversation opened. Load a model to continue." if not client.is_model_loaded() else "Conversation opened")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_models_dir = CATALOG.ensure_models_dir()
	var directory: String = RECENT.ensure_root()
	_recent_dir = directory.path_join("recent")
	DirAccess.make_dir_recursive_absolute(_recent_dir)
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("Cannot create settings folder: " + error_string(error))
	_settings_path = directory.path_join("settings.cfg")
	_preferences.load(_settings_path)
	_theme_name = String(_preferences.get_value("appearance", "theme", "Dark"))
	_ui_scale = clampf(float(_preferences.get_value("appearance", "ui_scale", 1.0)), 0.8, 1.35)
	client = CLIENT.new()
	client.token_received.connect(_on_token_received)
	client.generation_finished.connect(_on_generation_finished)
	client.generation_failed.connect(_on_generation_failed)
	client.error_occurred.connect(_set_status)
	_build_ui()
	_build_networking()
	_build_library()
	_apply_appearance()
	_add_message("assistant", "Hi! I'm **CodisAI**. Load a local model or download one from the model library to start chatting.")
	resized.connect(_reflow)
	_chat_scroll.resized.connect(_reflow)
	call_deferred("_reflow")
	if not CLIENT.is_runtime_available():
		_set_status(CLIENT.get_runtime_error())

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, caption: String) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _set_mouse_policy(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if control is BaseButton:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
		elif control is TextEdit or control is CodeEdit or control is LineEdit or control is RichTextLabel or control is ScrollContainer or control is HSplitContainer or control is SpinBox or control is Tree or control is ItemList or control is Range:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
	for child: Node in node.get_children():
		_set_mouse_policy(child)

func _style(color: Color, margin: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _build_ui() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_split = HSplitContainer.new()
	_split.name = "Layout"
	_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_split.add_theme_constant_override("separation", 8)
	add_child(_split)
	_sidebar = PanelContainer.new()
	_sidebar.custom_minimum_size.x = 300
	_sidebar.size_flags_horizontal = Control.SIZE_FILL
	_split.add_child(_sidebar)
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	_sidebar.add_child(side)
	var brand: HBoxContainer = HBoxContainer.new()
	side.add_child(brand)
	var logo: TextureRect = TextureRect.new()
	logo.texture = AVATAR
	logo.custom_minimum_size = Vector2(48, 48)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(logo)
	var brand_text: VBoxContainer = VBoxContainer.new()
	brand_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(brand_text)
	_label(brand_text, "CodisAI").add_theme_font_size_override("font_size", 24)
	_label(brand_text, "Local GGUF chat")
	var actions: HBoxContainer = HBoxContainer.new()
	side.add_child(actions)
	_button(actions, "Load file", func() -> void: _model_picker.popup_centered_ratio(0.75))
	_button(actions, "Folder", func() -> void: OS.shell_open(_models_dir))
	var library_separator: HSeparator = HSeparator.new()
	library_separator.name = "ModelLibrarySeparator"
	library_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(library_separator)
	_label(side, "MODEL LIBRARY")
	var library_scroll: ScrollContainer = ScrollContainer.new()
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(library_scroll)
	_library_list = VBoxContainer.new()
	_library_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_list.add_theme_constant_override("separation", 12)
	library_scroll.add_child(_library_list)
	_hide_scroll_handles(library_scroll)
	_dl_label = _label(side, "")
	_dl_bar = ProgressBar.new()
	_dl_bar.visible = false
	side.add_child(_dl_bar)
	_retry_button = _button(side, "Resume download", _retry_download)
	_retry_button.tooltip_text = "Retry from the beginning"
	_retry_button.visible = false
	_status_label = _label(side, "No model loaded")
	_status_label.clip_text = true
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(main)
	var header: HBoxContainer = HBoxContainer.new()
	main.add_child(header)
	_sidebar_button = _button(header, "", _toggle_sidebar)
	_sidebar_button.name = "SidebarToggle"
	_sidebar_button.tooltip_text = "Hide sidebar"
	_sidebar_button.custom_minimum_size = Vector2(44, 44)
	_sidebar_icon = TextureRect.new()
	_sidebar_icon.texture = SIDEBAR_ICON
	_sidebar_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sidebar_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sidebar_button.add_child(_sidebar_icon)
	_sidebar_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sidebar_icon.offset_left = -12.0
	_sidebar_icon.offset_top = -12.0
	_sidebar_icon.offset_right = 12.0
	_sidebar_icon.offset_bottom = 12.0
	_sidebar_icon.pivot_offset = Vector2(12, 12)
	_model_label = _label(header, "No model loaded")
	_model_label.clip_text = true
	_model_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_model_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var recent_button: Button = _button(header, "", _show_recent)
	recent_button.name = "RecentButton"
	recent_button.tooltip_text = "Recent conversations"
	recent_button.custom_minimum_size = Vector2(44, 44)
	var settings_button: Button = _button(header, "", func() -> void: _settings_window.popup_centered())
	settings_button.name = "SettingsButton"
	settings_button.tooltip_text = "Settings"
	settings_button.custom_minimum_size = Vector2(44, 44)
	var new_chat_button: Button = _button(header, "", _new_chat)
	new_chat_button.name = "NewChatButton"
	new_chat_button.tooltip_text = "New chat"
	new_chat_button.custom_minimum_size = Vector2(44, 44)
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_chat_scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	_chat_scroll.add_child(margin)
	_chat_list = VBoxContainer.new()
	_chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_list.add_theme_constant_override("separation", 16)
	margin.add_child(_chat_list)
	_hide_scroll_handles(_chat_scroll)
	_attachment_label = _label(main, "")
	_attachment_label.visible = false
	var composer_margin: MarginContainer = MarginContainer.new()
	composer_margin.name = "ComposerBottomSpacing"
	composer_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer_margin.add_theme_constant_override("margin_bottom", 14)
	main.add_child(composer_margin)
	var composer: HBoxContainer = HBoxContainer.new()
	composer.name = "Composer"
	composer.custom_minimum_size.y = 68
	composer.add_theme_constant_override("separation", 8)
	composer_margin.add_child(composer)
	_prompt_input = TextEdit.new()
	_prompt_input.name = "Prompt"
	_prompt_input.placeholder_text = "Message CodisAI… (Shift+Enter for a new line)"
	_prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_input.scroll_fit_content_height = true
	_prompt_input.custom_minimum_size.y = 52
	_prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_prompt_input.gui_input.connect(_on_prompt_input)
	var attachment_alignment: VBoxContainer = VBoxContainer.new()
	attachment_alignment.name = "AttachmentButtonAlignment"
	attachment_alignment.custom_minimum_size.x = 44
	attachment_alignment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	composer.add_child(attachment_alignment)
	var attachment_spacer: Control = Control.new()
	attachment_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attachment_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attachment_alignment.add_child(attachment_spacer)
	_attachment_button = _button(attachment_alignment, "", func() -> void: _document_picker.popup_centered_ratio(0.7))
	_attachment_button.custom_minimum_size = Vector2(44, 44)
	_attachment_button.custom_maximum_size.y = 44
	_attachment_button.tooltip_text = "Attach text document"
	composer.add_child(_prompt_input)
	var send_alignment: VBoxContainer = VBoxContainer.new()
	send_alignment.name = "SendButtonAlignment"
	send_alignment.custom_minimum_size.x = 44
	send_alignment.size_flags_horizontal = Control.SIZE_SHRINK_END
	send_alignment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	composer.add_child(send_alignment)
	var send_spacer: Control = Control.new()
	send_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	send_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	send_alignment.add_child(send_spacer)
	_send_button = _button(send_alignment, "", _send_prompt)
	_send_button.theme_type_variation = "PrimaryButton"
	_send_button.custom_minimum_size = Vector2(44, 44)
	_send_button.custom_maximum_size.y = 44
	_send_button.tooltip_text = "Send message"
	_model_picker = FileDialog.new()
	_model_picker.access = FileDialog.ACCESS_FILESYSTEM
	_model_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_model_picker.filters = PackedStringArray(["*.gguf ; GGUF model"])
	_model_picker.current_dir = _models_dir
	_model_picker.file_selected.connect(_load_model_path)
	add_child(_model_picker)
	_document_picker = FileDialog.new()
	_document_picker.title = "Attach text document"
	_document_picker.access = FileDialog.ACCESS_FILESYSTEM
	_document_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_document_picker.filters = PackedStringArray(["*.txt,*.md,*.csv,*.json,*.xml,*.log ; Text documents"])
	_document_picker.file_selected.connect(_attach_document)
	add_child(_document_picker)
	_build_settings()
	_build_recent()
	_set_mouse_policy(_split)
	_set_mouse_policy(_settings_window)
	_set_mouse_policy(_model_picker)
	_set_mouse_policy(_document_picker)
	# Sidebar is non-expanding: its minimum width is the default split origin.
	_last_split_offset = clampi(int(_preferences.get_value("layout", "split_offset", 0)), 0, 160)
	_split.split_offset = _last_split_offset
	_split.dragged.connect(func(offset: int) -> void:
		_last_split_offset = offset
		_save_preferences()
		_reflow()
	)

func _hide_scroll_handles(scroll: ScrollContainer) -> void:
	for bar: ScrollBar in [scroll.get_v_scroll_bar(), scroll.get_h_scroll_bar()]:
		bar.modulate.a = 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_settings() -> void:
	_settings_window = Window.new()
	_settings_window.title = "CodisAI Settings"
	_settings_window.size = Vector2i(520, 520)
	_settings_window.visible = false
	_settings_window.close_requested.connect(_settings_window.hide)
	add_child(_settings_window)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	var settings_panel: PanelContainer = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_window.add_child(settings_panel)
	settings_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_label(content, "Generation & appearance")
	var defaults: Dictionary = {"context_size": 2048, "max_tokens": 256, "temperature": 0.7, "threads": 0}
	for key: String in defaults:
		var row: HBoxContainer = HBoxContainer.new()
		content.add_child(row)
		_label(row, key.capitalize()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin: SpinBox = SpinBox.new()
		spin.min_value = 256 if key == "context_size" else (1 if key == "max_tokens" else 0)
		spin.max_value = 32768 if key == "context_size" else (4096 if key == "max_tokens" else (2 if key == "temperature" else 64))
		spin.step = 0.05 if key == "temperature" else 1.0
		spin.value = float(_preferences.get_value("generation", key, defaults[key]))
		row.add_child(spin)
		_generation_inputs[key] = spin
		spin.value_changed.connect(func(_value: float) -> void: _save_preferences())
	var themes: OptionButton = OptionButton.new()
	for caption: String in ["Dark", "AMOLED", "Light"]:
		themes.add_item(caption)
	themes.select(maxi(0, ["Dark", "AMOLED", "Light"].find(_theme_name)))
	content.add_child(themes)
	themes.item_selected.connect(func(index: int) -> void:
		_theme_name = themes.get_item_text(index)
		_apply_appearance()
		_save_preferences()
	)
	var scales: OptionButton = OptionButton.new()
	for factor: float in [0.8, 0.9, 1.0, 1.1, 1.2, 1.35]:
		scales.add_item("UI scale: %d%%" % roundi(factor * 100))
		scales.set_item_metadata(scales.item_count - 1, factor)
		if is_equal_approx(factor, _ui_scale):
			scales.select(scales.item_count - 1)
	content.add_child(scales)
	scales.item_selected.connect(func(index: int) -> void:
		_ui_scale = float(scales.get_item_metadata(index))
		_apply_appearance()
		_save_preferences()
	)
	var bottom_spacer: Control = Control.new()
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_spacer)
	_button(content, "Done", _settings_window.hide)

func _generation_options() -> Dictionary:
	var options: Dictionary = {}
	for key: String in _generation_inputs:
		var spin: SpinBox = _generation_inputs[key]
		options[key] = spin.value if key == "temperature" else int(spin.value)
	return options

func _save_preferences() -> void:
	_preferences.set_value("appearance", "theme", _theme_name)
	_preferences.set_value("appearance", "ui_scale", _ui_scale)
	_preferences.set_value("layout", "split_offset", _last_split_offset)
	for key: String in _generation_inputs:
		_preferences.set_value("generation", key, _generation_options()[key])
	var error: Error = _preferences.save(_settings_path)
	if error != OK:
		_set_status("Settings save failed: " + error_string(error))

func _apply_appearance() -> void:
	var light: bool = _theme_name == "Light"
	var fg: Color = Color("#18202a") if light else Color("#e6e9ef")
	var panel: Color = Color("#e5e9f0") if light else (Color("#08090b") if _theme_name == "AMOLED" else Color("#1d222c"))
	_background.color = Color("#f4f6fa") if light else (Color.BLACK if _theme_name == "AMOLED" else Color("#101116"))
	var ui_theme: Theme = Theme.new()
	for type_name: String in ["Label", "Button", "TextEdit", "LineEdit", "OptionButton", "PopupMenu", "Tree", "ItemList"]:
		ui_theme.set_color("font_color", type_name, fg)
	for type_name: String in ["Button", "OptionButton"]:
		for color_name: String in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			ui_theme.set_color(color_name, type_name, fg)
		ui_theme.set_color("font_disabled_color", type_name, Color("#64748b") if light else Color("#94a3b8"))
	for type_name: String in ["TextEdit", "LineEdit", "Tree", "ItemList"]:
		ui_theme.set_color("font_selected_color", type_name, Color.WHITE)
	ui_theme.set_color("font_readonly_color", "TextEdit", fg)
	ui_theme.set_color("font_uneditable_color", "LineEdit", fg)
	ui_theme.set_color("caret_color", "TextEdit", fg)
	ui_theme.set_color("caret_color", "LineEdit", fg)
	ui_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	ui_theme.set_color("font_disabled_color", "PopupMenu", Color("#64748b") if light else Color("#94a3b8"))
	ui_theme.set_stylebox("panel", "PopupMenu", _style(panel))
	ui_theme.set_stylebox("hover", "PopupMenu", _style(Color("#2563eb"), 8))
	for type_name: String in ["Tree", "ItemList", "PanelContainer"]:
		ui_theme.set_stylebox("panel", type_name, _style(panel))
	ui_theme.set_color("default_color", "RichTextLabel", fg)
	ui_theme.set_color("font_placeholder_color", "TextEdit", Color("#596579") if light else Color("#9ca3af"))
	for type_name: String in ["Button", "OptionButton", "TextEdit", "LineEdit"]:
		ui_theme.set_stylebox("normal", type_name, _style(panel, 8))
		ui_theme.set_stylebox("hover", type_name, _style(panel.darkened(0.08) if light else panel.lightened(0.12), 8))
		ui_theme.set_stylebox("pressed", type_name, _style(panel.darkened(0.14) if light else panel.lightened(0.2), 8))
		ui_theme.set_stylebox("disabled", type_name, _style(panel, 8))
	ui_theme.set_type_variation("PrimaryButton", "Button")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		ui_theme.set_stylebox(state, "PrimaryButton", _style(Color("#2563eb") if state != "hover" else Color("#1d4ed8"), 10))
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		ui_theme.set_color(color_name, "PrimaryButton", Color.WHITE)
	theme = ui_theme
	_settings_window.theme = ui_theme
	_recent_window.theme = ui_theme
	_model_picker.theme = ui_theme
	_document_picker.theme = ui_theme
	_sidebar.add_theme_stylebox_override("panel", _style(panel))
	_sidebar_icon.texture = _tinted_icon(SIDEBAR_ICON, fg)
	_attachment_button.icon = _tinted_icon(MORE_ICON, fg, true)
	_send_button.icon = _tinted_icon(SEND_ICON, Color.WHITE, true)
	var recent_button: Button = find_child("RecentButton", true, false) as Button
	var settings_button: Button = find_child("SettingsButton", true, false) as Button
	var new_chat_button: Button = find_child("NewChatButton", true, false) as Button
	recent_button.icon = _tinted_icon(RECENT_ICON, fg, true)
	settings_button.icon = _tinted_icon(SETTINGS_ICON, fg, true)
	new_chat_button.icon = _tinted_icon(NEW_CHAT_ICON, fg, true)
	_send_button.icon = _tinted_icon(SEND_ICON, fg, true)
	for icon_button: Button in [recent_button, settings_button, new_chat_button, _send_button]:
		icon_button.expand_icon = true
		icon_button.custom_minimum_size = Vector2(44, 44)
	_send_button.expand_icon = true
	get_tree().root.content_scale_factor = _ui_scale
	for message: Dictionary in _messages:
		_style_message(message)

func _toggle_sidebar() -> void:
	_sidebar.visible = not _sidebar.visible
	_sidebar_button.tooltip_text = "Hide sidebar" if _sidebar.visible else "Show sidebar"
	if _sidebar_rotation_tween != null and _sidebar_rotation_tween.is_running():
		_sidebar_rotation_tween.kill()
	_sidebar_rotation_tween = create_tween()
	_sidebar_rotation_tween.tween_property(_sidebar_icon, "rotation", 0.0 if _sidebar.visible else PI, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	call_deferred("_reflow")

func _build_library() -> void:
	for child: Node in _library_list.get_children():
		_library_list.remove_child(child)
		child.queue_free()
	var local: Array = CATALOG.scan_local(_models_dir)
	for entry: Dictionary in CATALOG.MODELS:
		var card: VBoxContainer = VBoxContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_library_list.add_child(card)
		_label(card, String(entry["name"]))
		_label(card, "%s params · %s · ~%d MB · %s" % [entry["params"], entry["quant"], entry["size_mb"], entry["license"]]).add_theme_font_size_override("font_size", 12)
		_label(card, String(entry["description"])).add_theme_font_size_override("font_size", 12)
		var path: String = CATALOG.installed_path(entry, local)
		var actions: HBoxContainer = HBoxContainer.new()
		card.add_child(actions)
		if path.is_empty():
			var download: Button = _button(actions, "Download", _download_model.bind(entry))
			download.disabled = _downloading
			download.theme_type_variation = "PrimaryButton"
			download.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			var load_button: Button = _button(actions, "Load (installed)", _load_model_path.bind(path))
			load_button.disabled = client.is_generating()
			load_button.theme_type_variation = "PrimaryButton"
			load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_button(actions, "Remove model", _remove_downloaded_model.bind(path)).disabled = client.is_generating()

func _load_model_path(path: String) -> void:
	if _loading:
		return
	if client.is_generating():
		_set_status("Stop generation before changing models.")
		return
	_loading = true
	_set_status("Loading " + path.get_file() + "…")
	await get_tree().process_frame
	if client.is_model_loaded():
		client.unload_model()
	_current_entry = CATALOG.find_by_filename(path.get_file())
	if client.load_model(path, _generation_options()):
		_model_label.text = String(_current_entry.get("name", path.get_file()))
		_set_status("Ready")
	else:
		_model_label.text = "No model loaded"
		_set_status(client.get_last_error())
	_loading = false

func _remove_downloaded_model(path: String) -> void:
	if client.is_generating():
		_set_status("Stop generation before removing a model.")
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.theme = theme
	dialog.dialog_text = "Delete the downloaded GGUF file?\n" + path.get_file()
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if client.get_model_path() == path:
			client.unload_model()
			_current_entry.clear()
			_history.clear()
			_model_label.text = "No model loaded"
		var error: Error = DirAccess.remove_absolute(path)
		_set_status("Model removed" if error == OK else "Removal failed: " + error_string(error))
		_build_library()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _copy_response(message: Dictionary) -> void:
	DisplayServer.clipboard_set(String(message["text"]))
	_set_status("Response copied to clipboard")

func _tinted_icon(source: Texture2D, color: Color, small: bool = false) -> Texture2D:
	var image: Image = source.get_image()
	if small:
		image.resize(24, 24, Image.INTERPOLATE_LANCZOS)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, pixel.a))
	return ImageTexture.create_from_image(image)

func _add_message(role: String, text: String) -> Dictionary:
	var row: HBoxContainer = HBoxContainer.new()
	_chat_list.add_child(row)
	if role == "user":
		var spacer: Control = Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
	else:
		var avatar: TextureRect = TextureRect.new()
		avatar.texture = AVATAR
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.custom_minimum_size = Vector2(36, 36)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(avatar)
	var bubble: PanelContainer = PanelContainer.new()
	if role == "assistant":
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bubble)
	var column: VBoxContainer = VBoxContainer.new()
	bubble.add_child(column)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	var message: Dictionary = {"role": role, "text": text, "bubble": bubble, "content": content}
	if role == "user":
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	_messages.append(message)
	_render_message(message)
	_style_message(message)
	_reflow()
	_scroll_bottom()
	return message

func _style_message(message: Dictionary) -> void:
	var light: bool = _theme_name == "Light"
	var user: bool = message["role"] == "user"
	var background: Color = Color("#d5e5ff") if light and user else (Color("#e5e9f0") if light else (Color("#2456a6") if user else Color("#1d222c")))
	(message["bubble"] as PanelContainer).add_theme_stylebox_override("panel", _style(background))
	var content: VBoxContainer = message["content"]
	for child: Node in content.get_children():
		if child is CODE:
			(child as CODE).set_copy_color(Color("#18202a") if light else Color.WHITE)

func _render_message(message: Dictionary) -> void:
	var content: VBoxContainer = message["content"]
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var parts: PackedStringArray = String(message["text"]).split("```")
	for index: int in range(parts.size()):
		var part: String = parts[index]
		if index % 2 == 1:
			var line_end: int = part.find("\n")
			var language: String = part.substr(0, line_end).strip_edges() if line_end >= 0 else ""
			var code: String = part.substr(line_end + 1) if line_end >= 0 else part
			var code_block: CODE = CODE.new(code, language)
			content.add_child(code_block)
			code_block.set_copy_visible(message["role"] == "assistant")
			code_block.set_copy_color(Color("#18202a") if _theme_name == "Light" else Color.WHITE)
		elif not part.is_empty():
			var body: RichTextLabel = RichTextLabel.new()
			body.bbcode_enabled = true
			body.selection_enabled = true
			body.fit_content = true
			body.scroll_active = false
			body.mouse_filter = Control.MOUSE_FILTER_STOP
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.text = _markdown(part)
			content.add_child(body)
			if message["role"] == "assistant":
				var touch_copy: TOUCH_COPY = TOUCH_COPY.new()
				body.add_child(touch_copy)
				touch_copy.setup(body, _copy_response.bind(message))

func _markdown(text: String) -> String:
	var escaped: String = text.replace("[", "[lb]")
	var bold: RegEx = RegEx.new()
	bold.compile("\\*\\*(.+?)\\*\\*")
	return bold.sub(escaped, "[b]$1[/b]", true)

func _reflow() -> void:
	if _chat_scroll == null:
		return
	for message: Dictionary in _messages:
		var bubble: PanelContainer = message["bubble"] as PanelContainer
		if message["role"] == "assistant":
			bubble.custom_minimum_size.x = 0.0
		else:
			var longest: int = 0
			for line: String in String(message["text"]).split("\n"):
				longest = maxi(longest, line.length())
			bubble.custom_minimum_size.x = clampf(40.0 + longest * 8.0, 140.0, maxf(140.0, _chat_list.size.x - 40.0))

func _scroll_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)

func _on_prompt_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and not event.shift_pressed:
		_send_prompt()
		_prompt_input.accept_event()

func _send_prompt() -> void:
	if client.is_generating():
		client.cancel_generation()
		return
	var text: String = _prompt_input.text.strip_edges()
	if text.is_empty():
		return
	if not client.is_model_loaded():
		_set_status("Load a model first.")
		return
	_add_message("user", text)
	for attachment: Dictionary in _attached_documents:
		text += "\n\n[Attached document: %s]\n%s" % [attachment["name"], attachment["text"]]
	_attached_documents.clear()
	_attachment_label.visible = false
	_prompt_input.clear()
	_history.append({"role": "user", "content": text})
	_save_recent()
	_start_generation()

func _start_generation() -> void:
	_current_text = ""
	_active_response = _add_message("assistant", "")
	_send_button.tooltip_text = "Stop generation"
	_set_status("Generating…")
	var prompt: String = PROMPT.build(_history, String(_current_entry.get("template", "chatml")))
	if not client.generate_async(prompt, _generation_options()):
		_on_generation_failed(client.get_last_error())

func _on_token_received(token: String) -> void:
	_current_text += token
	if not _active_response.is_empty():
		_active_response["text"] = _current_text
		_render_message(_active_response)
		_reflow()
		_scroll_bottom()

func _on_generation_finished(text: String, cancelled: bool) -> void:
	var final_text: String = text if not text.is_empty() else _current_text
	if not _active_response.is_empty():
		_active_response["text"] = final_text
		_render_message(_active_response)
	_history.append({"role": "assistant", "content": final_text})
	_active_response = {}
	_send_button.tooltip_text = "Send message"
	_set_status("Stopped" if cancelled else "Ready")
	_save_recent()
	_reflow()

func _on_generation_failed(message: String) -> void:
	_send_button.tooltip_text = "Send message"
	_active_response = {}
	_set_status(message)

func _new_chat() -> void:
	if client.is_generating():
		_set_status("Stop generation before starting a new chat.")
		return
	_recent_id = ""
	for child: Node in _chat_list.get_children():
		_chat_list.remove_child(child)
		child.queue_free()
	_messages.clear()
	_history.clear()
	_attached_documents.clear()
	_attachment_label.visible = false
	_add_message("assistant", "New conversation started. What would you like to talk about?")

func _attach_document(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Cannot read document: " + path)
		return
	if file.get_length() > 1048576:
		_set_status("Choose a text document smaller than 1 MB.")
		return
	_attached_documents.append({"name": path.get_file(), "text": file.get_as_text()})
	_attachment_label.text = "%d document(s) attached" % _attached_documents.size()
	_attachment_label.visible = true

func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _build_networking() -> void:
	_meta_request = HTTPRequest.new()
	_download_request = HTTPRequest.new()
	_meta_request.timeout = 30
	_download_request.use_threads = true
	add_child(_meta_request)
	add_child(_download_request)
	_meta_request.request_completed.connect(_on_metadata_completed)
	_download_request.request_completed.connect(_on_download_completed)

func _download_model(entry: Dictionary) -> void:
	if _downloading:
		return
	_pending_entry = entry.duplicate()
	_downloading = true
	_download_failed = false
	_retry_button.visible = false
	_dl_label.text = "Resolving " + String(entry["name"]) + "…"
	_build_library()
	var error: Error = _meta_request.request(CATALOG.api_url(String(entry["repo"])))
	if error != OK:
		_fail_download("Metadata request failed: " + error_string(error))

func _on_metadata_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail_download("Metadata request failed (HTTP %d)." % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail_download("Invalid metadata response.")
		return
	var filename: String = ""
	var expected: String = String(_pending_entry["file"])
	var quant: String = String(_pending_entry["quant"]).to_lower()
	for sibling: Dictionary in parsed.get("siblings", []):
		var candidate: String = String(sibling.get("rfilename", ""))
		if candidate == expected:
			filename = candidate
			break
		if filename.is_empty() and candidate.to_lower().ends_with(".gguf") and quant in candidate.to_lower() and "-0000" not in candidate:
			filename = candidate
	if filename.is_empty():
		_fail_download("No matching single-file GGUF found in repository.")
		return
	_pending_path = _models_dir.path_join(filename.get_file())
	_download_request.download_file = _pending_path + ".part"
	_dl_bar.visible = true
	_dl_label.text = "Downloading " + filename.get_file()
	var error: Error = _download_request.request(CATALOG.download_url(String(_pending_entry["repo"]), filename))
	if error != OK:
		_fail_download("Download could not start: " + error_string(error))

static func keyboard_layout_inset(keyboard_height: int, screen_height: float, layout_bottom: float, pixels_per_unit: float) -> float:
	if keyboard_height <= 0 or pixels_per_unit <= 0.0:
		return 0.0
	# Only reserve overlap: some mobile OS configurations already resize the window.
	return maxf(0.0, layout_bottom - (screen_height - keyboard_height)) / pixels_per_unit

func _update_keyboard_layout() -> void:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	var keyboard_height: int = DisplayServer.virtual_keyboard_get_height()
	var screen_transform: Transform2D = get_viewport().get_screen_transform() * get_global_transform_with_canvas()
	var bottom: Vector2 = screen_transform * Vector2(0.0, size.y)
	var screen_height: float = float(DisplayServer.screen_get_size().y)
	var inset: float = keyboard_layout_inset(keyboard_height, screen_height, bottom.y, screen_transform.y.length())
	if not is_equal_approx(_split.offset_bottom, -inset):
		_split.offset_bottom = -inset

func _process(_delta: float) -> void:
	_update_keyboard_layout()
	if _downloading and _dl_bar.visible:
		var total: int = _download_request.get_body_size()
		var received: int = _download_request.get_downloaded_bytes()
		_dl_bar.value = 100.0 * received / total if total > 0 else 0.0
		_dl_bar.tooltip_text = CATALOG.format_bytes(received)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail_download("Download failed (HTTP %d). Retry starts from the beginning." % response_code)
		return
	var error: Error = DirAccess.rename_absolute(_pending_path + ".part", _pending_path)
	if error != OK:
		_fail_download("Could not finalize download: " + error_string(error))
		return
	_downloading = false
	_dl_bar.visible = false
	_dl_label.text = "Download complete"
	_build_library()

func _fail_download(message: String) -> void:
	_downloading = false
	_download_failed = true
	_dl_bar.visible = false
	_retry_button.visible = true
	_dl_label.text = message
	_build_library()

func _retry_download() -> void:
	if not _pending_entry.is_empty():
		_download_model(_pending_entry)

func _exit_tree() -> void:
	if client != null:
		client.cancel_generation()
