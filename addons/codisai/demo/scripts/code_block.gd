extends VBoxContainer
class_name CodisCodeBlock

const BG := Color("#11151c")
const FG := Color("#d8dee9")
const KEYWORD := Color("#c792ea")
const STRING_COLOR := Color("#c3e88d")
const COMMENT := Color("#7f8c98")
const NUMBER := Color("#f78c6c")
const FUNCTION := Color("#82aaff")
const SYMBOL := Color("#89ddff")

var _code_text: String = ""
var _code_edit: CodeEdit
var _copy_button: Button


func _init(code: String = "", language: String = "") -> void:
	_code_text = _normalize_indent(code)
	add_theme_constant_override("separation", 4)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var language_label: Label = Label.new()
	language_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	language_label.text = language.to_upper() if not language.is_empty() else "CODE"
	language_label.add_theme_color_override("font_color", Color("#9aa7bd"))
	language_label.add_theme_font_size_override("font_size", 10)
	bar.add_child(language_label)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var copy_button: Button = Button.new()
	_copy_button = copy_button
	var copy_icon: Texture2D = load("res://addons/codisai/demo/assets/copy_text.png") as Texture2D
	if copy_icon != null:
		copy_button.icon = _tinted_copy_icon(_copy_icon_color())
	copy_button.tooltip_text = "Copy code"
	copy_button.flat = true
	copy_button.custom_minimum_size = Vector2(32, 32)
	copy_button.custom_maximum_size = Vector2(32, 32)
	copy_button.pressed.connect(_copy_code)
	bar.add_child(copy_button)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	_code_edit = CodeEdit.new()
	_code_edit.text = _code_text
	_code_edit.editable = false
	_code_edit.selecting_enabled = true
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code_edit.custom_minimum_size.y = minf(320.0, maxf(44.0, float(_code_text.count("\n") + 1) * 20.0 + 16.0))
	_code_edit.add_theme_color_override("font_color", FG)
	_code_edit.add_theme_color_override("font_readonly_color", FG)
	_code_edit.add_theme_color_override("line_number_color", Color("#9aa7bd"))
	_code_edit.add_theme_color_override("background_color", BG)
	_code_edit.add_theme_font_size_override("font_size", 13)
	var highlighter: CodeHighlighter = CodeHighlighter.new()
	highlighter.number_color = NUMBER
	highlighter.function_color = FUNCTION
	highlighter.symbol_color = SYMBOL
	highlighter.add_color_region("\"", "\"", STRING_COLOR, false)
	highlighter.add_color_region("'", "'", STRING_COLOR, false)
	highlighter.add_color_region("#", "", COMMENT, true)
	highlighter.add_color_region("//", "", COMMENT, true)
	for keyword: String in ["func", "var", "const", "let", "return", "if", "else", "elif", "for", "while", "match", "class", "extends", "true", "false", "null", "and", "or", "not", "in", "def", "import", "from", "as", "async", "await", "new", "public", "private", "static", "void", "int", "float", "string", "bool", "var", "return", "print", "shader_type", "uniform", "vec2", "vec3", "vec4"]:
		highlighter.add_keyword_color(keyword, KEYWORD)
	_code_edit.syntax_highlighter = highlighter
	panel.add_child(_code_edit)


func _normalize_indent(source: String) -> String:
	var lines: PackedStringArray = source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	while not lines.is_empty() and lines[0].strip_edges().is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	var min_indent: int = 2147483647
	for line: String in lines:
		if line.strip_edges().is_empty():
			continue
		var indent: int = line.length() - line.strip_edges(true, false).length()
		min_indent = mini(min_indent, indent)
	if min_indent == 2147483647:
		min_indent = 0
	var normalized: PackedStringArray = PackedStringArray()
	for line: String in lines:
		normalized.append(line.substr(min_indent).replace("\t", "    "))
	return "\n".join(normalized)


func _copy_icon_color() -> Color:
	return Color(1.0 - BG.r, 1.0 - BG.g, 1.0 - BG.b, 1.0)


func _tinted_copy_icon(tint: Color) -> Texture2D:
	var source: Texture2D = load("res://addons/codisai/demo/assets/copy_text.png") as Texture2D
	if source == null:
		return null
	var image: Image = source.get_image()
	if image == null:
		return source
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			image.set_pixel(x, y, Color(tint.r, tint.g, tint.b, pixel.a))
	return ImageTexture.create_from_image(image)


func set_copy_visible(visible: bool) -> void:
	_copy_button.visible = visible


func set_copy_color(color: Color) -> void:
	_copy_button.icon = _tinted_copy_icon(color)


func _copy_code() -> void:
	DisplayServer.clipboard_set(_code_text)


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = Color("#303846")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
