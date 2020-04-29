extends "res://tools/modular/module.gd"

func _on_initialize() -> Dictionary:
	return { valid = true }

func get_module_name() -> String:
	return "example-app"

func get_signals() -> Array:
	return []


func _on_show_modules_pressed():
	_modular.show_modules()
