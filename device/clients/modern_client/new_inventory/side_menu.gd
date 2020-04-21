extends "res://clients/modern_client/new_inventory/slider.gd"

export (NodePath) var overlay_path

var _overlay: Control

func _get_overlay():
	#print("gettin it")
	if not _overlay:
		_overlay = get_node(overlay_path)
		if not _overlay:
			assert(false)
	return _overlay

func _set_level(new_level: float):
	._set_level(new_level)
	
	if new_level <= 0.2:
		_get_overlay().set_visible(false)
		modulate.a = 0
	else:
		_get_overlay().set_visible(true)
		new_level = min(1.0, max(0.0, new_level))
		modulate.a = new_level
		_get_overlay().modulate.a = new_level * 0.9
