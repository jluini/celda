extends Node2D

export (String) var item_key

export (int) var instance_number
export (Color) var color

export (int) var interact_angle

export (String, MULTILINE) var code

export (float) var walk_speed

var walking = false
var angle = 0

#warning-ignore:unused_signal
signal start_walking
#warning-ignore:unused_signal
signal stop_walking
#warning-ignore:unused_signal
signal angle_changed


var _compiled_script

var enabled = true

##############################

func init_item(compiler):
	#add_to_group("item")
	
	if code:
		_compiled_script = compiler.compile_text(code)
		
		if not _compiled_script.is_valid:
			print("Item '%s': script is invalid" % get_key())
			_compiled_script.print_errors()

func has_action(action_name: String) -> bool:
	return _compiled_script != null and _compiled_script.has_sequence(action_name)
	
	
func get_sequence(trigger_name: String) -> Dictionary:
	return _compiled_script.get_sequence(trigger_name) if _compiled_script else null

func get_sequence_with_parameter(trigger_name: String, param):
	return _compiled_script.get_sequence_with_parameter(trigger_name, param) if _compiled_script else null

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
func get_interact_position():
	return position_of_child_at("interact_position")

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

func teleport(target_pos):
	position = target_pos#set_position(target_pos)
	on_teleport(target_pos)

func get_angle():
	return angle

func set_angle(new_angle: int):
	new_angle = _normalize_angle(new_angle)
	
	angle = new_angle
	emit_signal("angle_changed", new_angle)

func walk(new_angle):
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
