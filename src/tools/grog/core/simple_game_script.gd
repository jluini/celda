extends "res://tools/grog/core/game_script.gd"

class_name SimpleGameScript

export (String, FILE, "*.grog") var script_path

var _compiled_script

func _prepare(compiler) -> Dictionary:
	if not script_path:
		return { valid = false, message = "GameScript: no filename" }
	
	var file = File.new()
	if not file.file_exists(script_path):
		return { valid = false, message = "File '%s' does not exist" % script_path }
	
	var ret = file.open(script_path, File.READ)
	
	if ret != OK:
		match ret:
			ERR_FILE_NOT_FOUND:
				return { valid = false, message = "File '%s' not found" % script_path }
			ERR_CANT_OPEN:
				return { valid = false, message = "Can't open '%s'" % script_path }
			_:
				return { valid = false, message = "Error %s loading file '%s'" % [ret, script_path] }
				
	# compile it
	
	var content = file.get_as_text()
	
	var compiled = compiler.compile(content, 2)
	
	if compiled.is_valid():
		_compiled_script = compiled
	
		return { valid = true }
	
	else:
		var message = "Script is invalid"
		print(message)
		compiled.print_errors()
		
		return { valid = false, message = message }

# TODO up these to superclass game_script?

func _get_routine(headers: Array, tool_parameter: String) -> Resource:
	return _compiled_script.get_routine(headers, tool_parameter)

func _get_item_actions(item_key: String) -> Array:
	return _compiled_script.get_sections([item_key], true)
