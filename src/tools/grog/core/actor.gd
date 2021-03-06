extends Node2D

export (float) var walk_speed = 300 # game units (pixels) per second

export (Color) var color = Color.white

var walking := false
#var orientation := 0

var _horizon_y : float = 0.0
var _default_y : float = 900.0

signal start_walking
signal stop_walking
signal orientation_changed # (new_angle)

# used when added to a new room
func setup(new_room: Node, position: Vector2, orientation: float):
	_set_room(new_room)
	teleport(position)
	set_orientation(orientation)
	stop() # triggers idle animation

func get_color():
	return color

func get_linear_scale() -> float:
	var y : float = position.y
	return (y - _horizon_y) / (_default_y - _horizon_y)

func get_speed() -> float:
	var _scale: float = scale.x
	return walk_speed * _scale

func teleport(new_position: Vector2):
	set_position(new_position)
	
	var y : float = position.y
	
	# TODO extract this logic
	var new_z = int(y)
	
	set_z_index(new_z)
	
	var scale : float = get_linear_scale()
	
	set_scale(Vector2(scale, scale))
	
	if is_inside_tree():
		get_tree().get_nodes_in_group("show_y")[0].text = "%04.2f" % y
		get_tree().get_nodes_in_group("show_scale")[0].text = "%4.4f" % scale

func walk(new_orientation: float):
	walking = true
	emit_signal("start_walking", new_orientation)

func stop():
	walking = false
	emit_signal("stop_walking")

func set_orientation(new_orientation: float):
	emit_signal("orientation_changed", new_orientation)

func _set_room(new_room: Node):
	_horizon_y = new_room.horizon_y as float
	_default_y = new_room.default_y as float
