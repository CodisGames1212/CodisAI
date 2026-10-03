class_name SidebarSplitHandle
extends HSplitContainer

var _dragging_from_center: bool = false


func _ready() -> void:
	dragging_enabled = true
	collapsed = false
	drag_area_margin_begin = 0
	drag_area_margin_end = 0
	custom_minimum_size = Vector2(0, 0)


func _input(event: InputEvent) -> void:
	var local_x: float = get_local_mouse_position().x
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _dragging_from_center and _near_divider(local_x):
			_dragging_from_center = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging_from_center:
			_dragging_from_center = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_from_center:
		var sidebar: Control = get_child(0) as Control
		var main: Control = get_child(1) as Control
		if sidebar != null and sidebar.visible and main != null:
			var minimum_sidebar: float = sidebar.get_combined_minimum_size().x
			var maximum_sidebar: float = size.x - main.get_combined_minimum_size().x
			var desired_sidebar: float = clampf(local_x, minimum_sidebar, maximum_sidebar)
			split_offset = int(desired_sidebar - size.x * 0.5)
			get_viewport().set_input_as_handled()


func _near_divider(x: float) -> bool:
	var divider_x: float = size.x * 0.5 + float(split_offset)
	return absf(x - divider_x) <= 10.0
