#tool
#
extends Label

export (String) var label_type = "" setget _set_label_type

func _ready():
	_update_theme_override()

func _update_theme_override():
	if label_type != "":
		
		
		var font = get_font(label_type)
		
		if font:
			add_font_override("font", font)
		else:
			print("No font '%s' in theme" % label_type)
	else:
		add_font_override("font", null)
	

func _set_label_type(new_label_type):
	label_type = new_label_type
	_update_theme_override()

#func _draw():
#	_update_theme_override()
	#print("Redrawing")
