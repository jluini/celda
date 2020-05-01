#tool
#
extends Label

export (String) var label_type = "" setget _set_label_type

# used to avoid infinite NOTIFICATION_THEME_CHANGED loop 
var _updating_theme = false

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
	



func _notification(what):
	match what:
		NOTIFICATION_THEME_CHANGED:
			if not _updating_theme:
				_updating_theme = true
				_update_theme_override()
				_updating_theme = false
			# else this was triggered by myself two lines above

func _set_label_type(new_label_type):
	label_type = new_label_type
	_update_theme_override()
