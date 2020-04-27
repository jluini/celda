extends "res://tools/grog/newcore/game_script.gd"

class_name SimpleGameScript

export (String, FILE, "*.grog") var script_path

var _compiled_data

func _prepare(compiler) -> Dictionary:
	if not script_path:
		return { result = false, msg = "GameScript: no filename" }
	
	var file = File.new()
	var ret = file.open(script_path, File.READ)
	
	if ret != OK:
		match ret:
			ERR_FILE_NOT_FOUND:
				return { result = false, msg = "File '%s' not found" % script_path }
			_:
				return { result = false, msg = "Error %s loading file '%s'" % [ret, script_path] }
				
	# compile it
	
	print("Continue here")
	
	var content = file.get_as_text()
	
	var compiled = compiler.new_compile(content, 2)
	
	if compiled.is_valid():
		_compiled_data = compiled
	
		return { result = true }
	
	else:
		var message = "Script is invalid"
		print(message)
		compiled.print_errors()
		
		return { result = false, msg = message }
