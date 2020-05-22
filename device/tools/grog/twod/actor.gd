extends Node2D

export (float) var walk_speed = 300 # game units (pixels) per second

export (Color) var color = Color.white

var walking := false
var angle := 0

var horizon : float = 266
var center : float = 896

signal start_walking
signal stop_walking
signal angle_changed # (new_angle)

func get_color():
	return color

func get_linear_scale() -> float:
	var y : float = position.y
	return (y - horizon) / (center - horizon)

func get_speed() -> float:
	return walk_speed * get_linear_scale()

func teleport(new_position: Vector2):
	set_position(new_position)
	
	var y : float = position.y
	
	# TODO extract this logic
	var new_z = int(y)
	
	set_z_index(new_z)
	
	var scale : float = get_linear_scale()
	
	set_scale(Vector2(scale, scale))

func walk(new_angle: int):
	angle = _normalize_angle(new_angle)
	walking = true
	emit_signal("start_walking", angle)

func stop():
	walking = false
	emit_signal("stop_walking")

func set_angle(new_angle: int):
	angle = _normalize_angle(new_angle)
	emit_signal("angle_changed", angle)

# TODO extract this logic
static func _normalize_angle(_angle: int) -> int:
	if _angle < 0:
		print("Negative angle")
		while _angle < 0:
			_angle += 360
	elif _angle >= 360:
		print("Angle greater than 360")
		while _angle >= 360:
			_angle -= 360
	return _angle
