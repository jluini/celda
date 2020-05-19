extends Node2D

export (String) var item_key

export (int) var instance_number
export (Color) var color

export (int) var interact_angle

export (float) var walk_speed # game units per second

var walking = false
var angle = 0

signal start_walking
signal stop_walking
signal angle_changed

var enabled = true

##############################

func is_enabled():
	return enabled
	
##############################

# abstract method
func on_teleport(_target_pos):
	pass

func position_of_child_at(position_path: NodePath):
	if position_path and has_node(position_path):
		return position + get_node(position_path).position
	else:
		return position
	
# relative position
# TODO rename to interaction_position?
func get_interact_position():
	return position_of_child_at("interact_position")

# TODO rename to interaction_angle?
func get_interact_angle():
	return interact_angle

func enable():
	enabled = true
	visible = true

func disable():
	enabled = false
	visible = false

func get_id():
	if instance_number == 0:
		return get_key()
	else:
		return "%s.%s" % [get_key(), str(instance_number)]

func get_key():
	return item_key

### 

func teleport(target_pos: Vector2):
	position = target_pos
	on_teleport(target_pos)

func get_angle():
	return angle

func set_angle(new_angle: int):
	new_angle = _normalize_angle(new_angle)
	
	angle = new_angle
	emit_signal("angle_changed", new_angle)

func walk(new_angle: int):
	new_angle = _normalize_angle(new_angle)
	
	angle = new_angle
	walking = true
	emit_signal("start_walking", new_angle)

func stop():
	walking = false
	emit_signal("stop_walking")

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
