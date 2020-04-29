extends "res://tools/modular/module.gd"

func _on_initialize() -> Dictionary:
	return { valid = true }

func get_module_name() -> String:
	return "example"

func get_signals() -> Array:
	return []
	

func _on_play_uajari_pressed():
	_modular.broadcast("music", "start", ["uajari"])
