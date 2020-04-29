extends Control

signal theme_selected

var _theme: Theme

func init_with_theme(theme_to_show: Theme):
	_theme = theme_to_show
	
	set_theme(theme_to_show)
	
	var theme_name = theme_to_show.get_name()
	
	$label.text = theme_name
	$themed_label.text = theme_name
	$custom_label.text = theme_name

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		emit_signal("theme_selected", _theme)
