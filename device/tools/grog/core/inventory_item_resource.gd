extends Resource

class_name InventoryItemResource

export (Texture) var texture

export (String, MULTILINE) var code

var _compiled_script

func compile(compiler):
	_compiled_script = compiler.compile(code, 1)
	if not _compiled_script.is_valid:
		print("Inventory item '%s' script is invalid:" % get_name())
		_compiled_script.print_errors()

func get_sequence(trigger_name: String) -> Dictionary:
	if not _compiled_script:
		print("Inventory item resource is not compiled")
		return {}
	
	if _compiled_script.is_valid and _compiled_script.has_sequence(trigger_name):
		return _compiled_script.get_sequence(trigger_name)
	else:
		# returns empty dict so it defaults to fallback
		return {}

func get_id():
	return get_name()
	
