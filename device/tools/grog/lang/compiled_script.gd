extends Resource

class_name CompiledScript

export (int) var levels = 2

var _valid: bool = true
var _initialized: bool = false

var _data: Dictionary = {}
var _errors: Array = []


func initialize(num_levels: int, data: Dictionary) -> bool:
	if _initialized:
		print("CompiledScript is already initialized")
		return false
	
	if not is_valid():
		print("Trying to initialize a CompiledScript with errors")
		return false
		
	if num_levels < 1:
		print("num_levels must be > 0 (it's %s)" % num_levels)
		return false
	
	levels = num_levels
	_initialized = true
	
	# TODO validate dict!
	_data = data
	
	return true

func add_error(new_error):
	_errors.append(new_error)
	_valid = false

func print_errors():
	for i in range(_errors.size()):
		_print_error(_errors[i])

func _print_error(err):
	print(err)

func get_routine(headers: Array, tool_parameter: String) -> Resource:
	if headers.size() != levels:
		print("Expecting %s headers (%s given)" % [levels, headers.size()])
		return null
	
	var level = 0
	var current_dict = _data
	var current_key
	
	while true:
		current_key = headers[level]
		
		if not current_dict.has(current_key):
			if level < levels - 1:
				var sublevels = headers.slice(0, level)
				print("Even '%s' is absent" % str(sublevels))
			
			return null
		
		if level == levels - 1:
			var routine = current_dict[current_key]
			
			var tool_required : bool = tool_parameter != ""
			var routine_has_tool : bool = routine.pattern != ""
			
			print("ignoring tool parameter matching (%s/%s)" % [tool_required, routine_has_tool])
			
			return routine
		
		level += 1
		current_dict = current_dict[current_key]
	
	# unreachable
	return null

func get_sections(headers: Array, only_straight_ones := false) -> Array:
	if headers.size() >= levels:
		print("Expecting less than %s headers (%s given)" % [levels, headers.size()])
		return []
	
	var level := 0
	var current_dict: Dictionary = _data
	
	while headers.size() > level:
		var current_key: String = headers[level]
		if not current_dict.has(current_key):
			print("Section '%s' not found at level %s" % [str(headers), level])
			return []
		
		level += 1
		current_dict = current_dict[current_key]
	
	var ret = []
	
	for trigger_name in current_dict:
		var routine = current_dict[trigger_name]
		if not only_straight_ones or not routine.has_pattern():
			ret.append(trigger_name)
	
	return ret

func is_valid():
	return _valid
