extends MenuButton

signal end_mode_selected

var _popup

func _ready():
	_popup = get_popup()
	_popup.connect("id_pressed", self, "_on_option_selected")

func _on_option_selected(_new_option):
	emit_signal("end_mode_selected", _new_option)
