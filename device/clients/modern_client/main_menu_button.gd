extends Control

signal pressed

export (bool) var is_pressed

export (String) var caption


export (float) var hover_off_value = 0.1
export (float) var hover_on_value = 0.6
export (float) var off_value = 0.0
export (float) var on_value = 0.5


func _ready():
	$label.text = caption

func click():
	emit_signal("pressed")

func set_pressed(new_pressed: bool):
	if is_pressed == new_pressed:
		return
	is_pressed = new_pressed
	_set_modulate(on_value if is_pressed else off_value)

func _set_modulate(val: float):
	self_modulate.a = val
	

func _on_mouse_entered():
	_set_modulate(hover_on_value if is_pressed else hover_off_value)

func _on_mouse_exited():
	_set_modulate(on_value if is_pressed else off_value)
