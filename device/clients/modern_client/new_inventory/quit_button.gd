extends Control

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var display = get_parent().get_parent().get_parent().get_parent()
		
		display._on_quit_button_pressed()
