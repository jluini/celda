extends "res://tools/modular/module.gd"

export (Array, Theme) var themes

export (int) var current_theme_index

onready var _theme_list = $theme_list

var _theme_views: Array

func _on_initialize() -> Dictionary:
	if not themes:
		return { valid = false, message = "no themes"}
	elif current_theme_index < 0 or current_theme_index >= themes.size():
		_log_error("invalid initial index %s" % current_theme_index)
		current_theme_index = 0
		
	var t = _get_current_theme()
	
	if t != _modular.get_theme():
		_log("setting theme '%s' at start" % t.get_name())
		_modular.set_theme(t)
	
	_theme_views = []
	
	# delete theme_view examples
	while _theme_list.get_child_count() > 0:
		var c = _theme_list.get_child(0)
		_theme_list.remove_child(c)
		c.queue_free()
	
	for index in range(themes.size()):
		var theme = themes[index]
		var theme_view = preload("res://tools/theming/theme_selector.tscn").instance()
		theme_view.init_with_theme(theme)
		theme_view.connect("theme_selected", self, "_on_theme_selected", [index])
		
		if index == current_theme_index:
			theme_view.select()
		
		_theme_list.add_child(theme_view)
		_theme_views.append(theme_view)
		
	
	return { valid = true }

func _get_current_theme():
	return themes[current_theme_index]

func get_module_name() -> String:
	return "theme-switcher"
	
func get_signals() -> Array:
	return []

func _on_theme_selected(new_theme: Theme, index: int):
	_theme_views[current_theme_index].unselect()
	_theme_views[index].select()
	_modular.change_theme(new_theme)
	current_theme_index = index
