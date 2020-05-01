extends Resource

class_name CompiledScript

export (int) var levels = 2

#var is_valid setget , _is_valid

# TODO remove this... it's for compatibility with old compiler code
#var is_valid setget, is_valid

var _valid: bool
var _initialized: bool

#var _dict: Dictionary
#var _sections: Array
var _data: Dictionary

var _errors: Array

func _init():
	_valid = true
	_initialized = false
	_errors = []

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

func has_sequence(headers: Array) -> bool:
	if levels < 0:
		print("Bad configuration")
		return false
	if headers.size() != levels:
		print("Expecting %s headers (%s given)" % [levels, headers.size()])
		return false
	
	var level = 0
	var current_dict = _data
	var current_key
	
	while true:
		current_key = headers[level]
		
		if not current_dict.has(current_key):
			if level < levels - 1:
				var sublevels = headers.slice(0, level)
				print("Even '%s' is absent" % str(sublevels))
			
			return false
		
		if level == levels - 1:
			return true
		
		level += 1
		current_dict = current_dict[current_key]
	
	# unreachable
	return false

func get_sequence(headers: Array):
	if levels < 0:
		print("Bad configuration")
		return null
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
			return current_dict[current_key]
		
		level += 1
		current_dict = current_dict[current_key]
	
	# unreachable
	return null

#func add_sequence(headers: Array, sequence) -> Dictionary:
#	if levels < 0:
#		return { result = false, message = "Bad configuration" }
#	if headers.size() != levels:
#		return { result = false, message = "Expecting %s headers (%s given)" % [levels, headers.size()] }
#
#	print("Adding sequence for %s" % str(headers))
#
#	var level = 0
#	var current_dict = _dict
#	var current_key
#
#	while true:
#		current_key = headers[level]
#		if level >= levels - 1:
#			break
#
#		if not current_dict.has(current_key):
#			print("Creating '%s' at level %s" % [current_key, level])
#			current_dict[current_key] = {}
#
#		current_dict = current_dict[current_key]
#		level += 1
#
#	if current_dict.has(current_key):
#		return { result = false, message = "Duplicated sequence for '%s'" % str(headers) }
#
#	print("Creating sequence for '%s' at level %s" % [current_key, level])
#
#	current_dict[current_key] = sequence
#
#	# TODO validate sequence?
#
#	return { result = true }

func is_valid():
	return _valid
