extends ColorRect

export (Color) var normal_color = Color(1, 1, 1, 0.156863)
export (Color) var tool_color = Color(1, 0.5, 0.5, 0.156863)

func show_rect(rect: Rect2, show_as_tool := false):
	set_position(rect.position)
	set_size(rect.size)
	
	set_frame_color(tool_color if show_as_tool else normal_color)
	
	show()
