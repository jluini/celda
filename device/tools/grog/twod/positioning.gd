tool

extends Node2D

var _line_width := 3.0
var _line_color := Color.white

var _line_start := 5.0
var _line_end := 40.0
var _head_length := 15.0
var _head_angle := 30.0

var _circle_radius := 20.0
var _circle_color := Color(0.96, 0.64, 0.38, 0.5)

func get_location() -> Vector2:
	return global_position

func get_orientation() -> float:
	return global_rotation_degrees

func _draw():
	if Engine.editor_hint:
		var center := Vector2.ZERO
		
		var dir: Vector2 = Vector2.RIGHT
		var dir_a: Vector2 = _dir_vector(-_head_angle)
		var dir_b: Vector2 = _dir_vector(+_head_angle)
		
		draw_circle(center, _circle_radius, _circle_color)
		
		var start: Vector2 = center + _line_start * dir
		var end: Vector2 = center + _line_end * dir
		
		draw_line(start, end, _line_color, _line_width)
		draw_line(end + dir_a * 1.0, end - dir_a * _head_length, _line_color, _line_width)
		draw_line(end + dir_b * 1.0, end - dir_b * _head_length, _line_color, _line_width)

static func _dir_vector(angle_degrees: float) -> Vector2:
	var angle_radians: float = deg2rad(angle_degrees)
	return Vector2(cos(angle_radians), sin(angle_radians))
