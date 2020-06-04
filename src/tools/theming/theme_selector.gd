extends Control

signal theme_selected

var _theme: Theme

var selected_alpha = 0.2
var unselected_alpha = 0.0

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

func select():
	$background.color.a = selected_alpha
	
func unselect():
	$background.color.a = unselected_alpha
