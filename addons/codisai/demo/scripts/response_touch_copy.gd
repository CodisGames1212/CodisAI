class_name CodisResponseTouchCopy
extends Node

## Copies the complete response after a stationary hold, without blocking scrolling.
var _timer: Timer
var _callback: Callable
var _control: Control
var _pointer: int = -2
var _origin: Vector2 = Vector2.ZERO

func setup(control: Control, callback: Callable) -> void:
	_control = control
	_callback = callback
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.6
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	control.gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_pointer = event.index
		_origin = _control.get_global_transform_with_canvas() * event.position
		_timer.start()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _pointer < 0:
		_pointer = -1
		_origin = _control.get_global_transform_with_canvas() * event.position
		_timer.start()

func _input(event: InputEvent) -> void:
	if _timer == null or _timer.is_stopped():
		return
	if event is InputEventScreenTouch:
		if not event.pressed or event.index != _pointer:
			cancel()
	elif event is InputEventScreenDrag and event.index == _pointer:
		if event.position.distance_to(_origin) > 16.0:
			cancel()
	elif event is InputEventMouseButton and not event.pressed and _pointer == -1:
		cancel()
	elif event is InputEventMouseMotion and _pointer == -1:
		if event.position.distance_to(_origin) > 16.0:
			cancel()

func cancel() -> void:
	_timer.stop()
	_pointer = -2

func _on_timeout() -> void:
	_pointer = -2
	if _callback.is_valid():
		_callback.call()
