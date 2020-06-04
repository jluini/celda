tool

extends Control

export (String) var text setget _set_text
export (Color) var color = Color.white setget _set_color

export (String) var label_type = "" setget _set_label_type

func _ready():
	pass

func _draw():
	var font: Font = get_font(label_type, "Label")
	var text_to_show = tr(text)
	
	var center = rect_size / 2
	var text_size = font.get_string_size(text_to_show)
	
	var pos = center
	#pos.x -= text_size.x / 2
	#pos.y += font.get_descent()
	
	pos -= text_size / 2
	pos.y += font.get_ascent()
	
	draw_string(font, pos, text_to_show, color)
	

func _set_color(new_color: Color):
	color = new_color
	update()
	
func _set_text(new_text: String):
	text = new_text
	update()
	
func _set_label_type(new_label_type: String):
	label_type = new_label_type
	update()

