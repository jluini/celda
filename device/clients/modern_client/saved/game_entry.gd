extends "res://tools/ui_tools/view.gd"

func target_changing(_old_target, _new_target):
	$label.text = _new_target.filename
