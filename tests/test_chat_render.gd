extends Node

const CODE_SCRIPT = preload("res://addons/codisai/demo/scripts/code_block.gd")


func test_code_block_dedents_and_trims_code() -> void:
	var code_block: CodisCodeBlock = CODE_SCRIPT.new("\n    func greet():\n        print(\"hi\")\n", "gdscript") as CodisCodeBlock
	assert(code_block._code_text == "func greet():\n    print(\"hi\")")
	code_block.free()


func test_code_block_has_read_only_highlighted_editor() -> void:
	var code_block: CodisCodeBlock = CODE_SCRIPT.new("func greet():\n    pass", "gdscript") as CodisCodeBlock
	var highlighter: CodeHighlighter = code_block._code_edit.syntax_highlighter as CodeHighlighter
	assert(highlighter != null)
	assert(highlighter.has_keyword_color("func"))
	assert(not code_block._code_edit.editable)
	code_block.free()
