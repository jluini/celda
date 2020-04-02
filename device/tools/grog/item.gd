extends Node2D

export (String) var item_key

export (int) var instance_number = 0
export (Color) var color

export (int) var interact_angle = 90

export (String, MULTILINE) var code

export (float) var walk_speed = 300 # pixels per second

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

func get_sequence(trigger_name: String) -> Dictionary:
	return _compiled_script.get_sequence(trigger_name) if _compiled_script else null

func get_sequence_with_parameter(trigger_name: String, param):
	return _compiled_script.get_sequence_with_parameter(trigger_name, param) if _compiled_script else null

func is_enabled():
	return enabled
	
##############################

func teleport(target_pos):
	position = target_pos#set_position(target_pos)
	on_teleport(target_pos)

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
