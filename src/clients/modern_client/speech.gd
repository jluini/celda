extends "res://tools/theming/themed_label.gd"

onready var _animation = $animation_player

func show_speech(speech: String, color: Color):
	text = speech
	
	# shrinks the height as much as possible
	call_deferred("_shrink_speech")
	
	set("custom_colors/font_color", color)
	_animation.play("show")

func hide_speech():
	_animation.play("hide")

func _shrink_speech():
	rect_size.y = 0
