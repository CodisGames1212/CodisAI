class_name TestCodisResponseUI
extends Node

const CHAT = preload("res://addons/codisai/demo/scripts/chatbox.gd")

func test_model_clipping_and_sidebar_center() -> void:
	var chat: CHAT = CHAT.new()
	chat.size = Vector2(1280, 800)
	get_tree().root.add_child(chat)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(chat._model_label.clip_text)
	assert(chat._model_label.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(chat._status_label.clip_text)
	assert(chat._status_label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var recent_button: Button = chat.find_child("RecentButton", true, false)
	var settings_button: Button = chat.find_child("SettingsButton", true, false)
	var new_chat_button: Button = chat.find_child("NewChatButton", true, false)
	assert(recent_button.text.is_empty() and recent_button.icon != null and recent_button.tooltip_text == "Recent conversations")
	assert(settings_button.text.is_empty() and settings_button.icon != null and settings_button.tooltip_text == "Settings")
	assert(new_chat_button.text.is_empty() and new_chat_button.icon != null and new_chat_button.tooltip_text == "New chat")
	assert(chat._send_button.text.is_empty() and chat._send_button.icon != null and chat._send_button.tooltip_text == "Send message")
	assert(chat._prompt_input.mouse_filter == Control.MOUSE_FILTER_PASS)
	assert(chat._prompt_input.scroll_fit_content_height)
	assert(chat._prompt_input.custom_minimum_size.y == 52.0)
	assert(chat._prompt_input.get_theme_stylebox("focus") is StyleBoxEmpty)
	assert(chat._chat_scroll.mouse_filter == Control.MOUSE_FILTER_PASS)
	assert(chat.find_child("Continue", true, false) == null)
	var composer: HBoxContainer = chat.find_child("Composer", true, false)
	assert(composer.get_child_count() == 3)
	var attachment_alignment: VBoxContainer = chat.find_child("AttachmentButtonAlignment", true, false)
	var send_alignment: VBoxContainer = chat.find_child("SendButtonAlignment", true, false)
	assert(composer.get_child(0) == attachment_alignment)
	assert(composer.get_child(1) == chat._prompt_input)
	assert(composer.get_child(2) == send_alignment)
	assert(composer.custom_minimum_size.y < 90.0)
	assert(chat._attachment_button.get_parent() == attachment_alignment)
	assert(chat._send_button.get_parent() == send_alignment)
	assert(chat._attachment_button.custom_minimum_size == Vector2(44, 44))
	assert(chat._send_button.custom_minimum_size == Vector2(44, 44))
	assert(attachment_alignment.size_flags_vertical == Control.SIZE_EXPAND_FILL)
	assert(send_alignment.size_flags_vertical == Control.SIZE_EXPAND_FILL)
	assert(attachment_alignment.get_child(0).size_flags_vertical == Control.SIZE_EXPAND_FILL)
	assert(send_alignment.get_child(0).size_flags_vertical == Control.SIZE_EXPAND_FILL)
	var composer_spacing: MarginContainer = chat.find_child("ComposerBottomSpacing", true, false)
	assert(composer_spacing.get_theme_constant("margin_bottom") >= 12)
	assert(chat._sidebar_button.mouse_filter == Control.MOUSE_FILTER_STOP)
	var icon_center: Vector2 = chat._sidebar_icon.position + chat._sidebar_icon.size * 0.5
	assert(icon_center.is_equal_approx(chat._sidebar_button.size * 0.5))
	assert(chat._sidebar_icon.pivot_offset == chat._sidebar_icon.size * 0.5)
	chat.queue_free()
	await get_tree().process_frame

func test_keyboard_inset_scaling_and_os_resize() -> void:
	assert(is_equal_approx(CHAT.keyboard_layout_inset(600, 2400.0, 2400.0, 3.0), 200.0))
	assert(is_zero_approx(CHAT.keyboard_layout_inset(0, 2400.0, 2400.0, 3.0)))
	assert(is_zero_approx(CHAT.keyboard_layout_inset(600, 2400.0, 1800.0, 3.0)))
	assert(is_equal_approx(CHAT.keyboard_layout_inset(600, 2400.0, 2100.0, 3.0), 100.0))

func test_response_only_copy_controls_and_light_contrast() -> void:
	var chat: CHAT = CHAT.new()
	get_tree().root.add_child(chat)
	await get_tree().process_frame
	var user: Dictionary = chat._add_message("user", "User prompt")
	var response: Dictionary = chat._add_message("assistant", "Response text")
	var separator: Node = chat._sidebar.find_child("ModelLibrarySeparator", true, false)
	assert(separator is HSeparator)
	assert((response["bubble"] as PanelContainer).size_flags_horizontal == Control.SIZE_EXPAND_FILL)
	assert(not user.has("copy"))
	assert(not response.has("copy"))
	chat._theme_name = "Light"
	chat._apply_appearance()
	assert(response["content"].get_child_count() == 1)
	assert(chat.theme.get_color("font_hover_color", "Button").r < 0.2)
	assert(chat.theme.get_color("font_color", "PopupMenu").r < 0.2)
	var body: RichTextLabel = response["content"].get_child(0)
	assert(body.selection_enabled)
	assert(body.get_child_count() == 1)
	assert(body.get_child(0) is CodisResponseTouchCopy)
	chat.queue_free()
	await get_tree().process_frame
