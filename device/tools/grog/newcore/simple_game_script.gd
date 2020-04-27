extends "res://tools/grog/newcore/game_script.gd"

class_name SimpleGameScript

export (String, FILE, "*.grog") var script_path

var _compiled_data

func _prepare(compiler) -> Dictionary:
	if not script_path:
		return { result = false, message = "GameScript: no filename" }
	
	var file = File.new()
	if not file.file_exists(script_path):
		return { result = false, message = "File '%s' does not exist" % script_path }
	
	var ret = file.open(script_path, File.READ)
	
	if ret != OK:
		match ret:
			ERR_FILE_NOT_FOUND:
				return { result = false, message = "File '%s' not found" % script_path }
			ERR_CANT_OPEN:
				return { result = false, message = "Can't open '%s'" % script_path }
			_:
				return { result = false, message = "Error %s loading file '%s'" % [ret, script_path] }
				
	# compile it
	
	var content = file.get_as_text()
	
	var compiled = compiler.compile(content, 2)
	
	if compiled.is_valid():
		_compiled_data = compiled
	
		return { result = true }
	
	else:
		var message = "Script is invalid"
		print(message)
		compiled.print_errors()
		
		return { result = false, message = message }

# TODO up these to superclass game_script?
func _has_sequence(headers: Array) -> bool:
	return _compiled_data.has_sequence(headers)

func _get_sequence(headers: Array) -> bool:
	return _compiled_data.get_sequence(headers)
