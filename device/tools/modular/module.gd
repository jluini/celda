extends Control

var _modular = null

var module_name = _get_module_name()

func initialize(p_modular) -> Dictionary:
	_modular = p_modular
	return _on_initialize()

func get_module_name(subcategory = ""):
	if not subcategory:
		return module_name
	else:
		return "%s/%s" % [module_name, subcategory]

func _get_module_name():
	return "no-name-yet"

# Logging utils

func _log(message: String, subcategory = "", level = 0):
	_modular.log_info(get_module_name(subcategory), message, level)
func _log_warning(message: String, subcategory = "", level = 0):
	_modular.log_warning(get_module_name(subcategory), message, level)
func _log_error(message: String, subcategory = "", level = 0):
	_modular.log_error(get_module_name(subcategory), message, level)

# Methods to override

func _on_initialize() -> Dictionary:
	_log_warning("override _on_initialize")
	
	return { valid = true }

func get_signals() -> Array:
	_log_warning("override get_signals")
	return []
