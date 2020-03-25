extends Node2D

export (String) var global_id
export (Color) var color

export (String, MULTILINE) var code

export (float) var walk_speed = 300 # pixels per second

#warning-ignore:unused_signal
signal start_walking
#warning-ignore:unused_signal
signal stop_walking

var _compiled_script: CompiledGrogScript

var enabled = true

##############################

func _ready():
	add_to_group("item")
	
	if code:
		if not grog.has_method("compile_text"):
			print("Warning: weird case")
			return
		
		_compiled_script = grog.compile_text(code)
		
		if not _compiled_script.is_valid:
			print("Item '%s': script is invalid" % global_id)
			_compiled_script.print_errors()

func get_sequence(trigger_name: String) -> Sequence:
	if _compiled_script and _compiled_script.is_valid and _compiled_script.has_sequence(trigger_name):
		return _compiled_script.get_sequence(trigger_name)
	else:
		# returns null so it defaults to fallback
		return null

func is_enabled():
	return enabled
	
##############################

func teleport(target_pos):
	position = target_pos
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
