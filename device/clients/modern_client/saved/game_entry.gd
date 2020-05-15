extends "res://tools/ui_tools/view.gd"

signal load_game_requested

func target_changing(_old_target, _new_target):
	$label.text = _new_target.filename

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		if target:
			var filename = target.filename
			emit_signal("load_game_requested", filename)
		# else this is the "no games" label
