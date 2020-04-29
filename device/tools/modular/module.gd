extends Control

var _modular = null

func initialize(p_modular) -> Dictionary:
	_modular = p_modular
	
	return _on_initialize()

# Logging utils

func _log(message: String, level = 0):
	_modular.log_info(get_module_name(), message, level)
func _log_warning(message: String, level = 0):
	_modular.log_warning(get_module_name(), message, level)
func _log_error(message: String, level = 0):
	_modular.log_error(get_module_name(), message, level)

# Methods to override

func _on_initialize() -> Dictionary:
	_log_warning("override _on_initialize")
	
	return { valid = true }

func get_module_name() -> String:
	_log_warning("override get_module_name")
	return "no-name"

func get_signals() -> Array:
	_log_warning("override get_signals")
	return []
