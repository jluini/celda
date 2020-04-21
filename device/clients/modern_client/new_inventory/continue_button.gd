extends Control

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		print("Continue")
		
		var menu = get_parent().get_parent()
		
		menu.close()
