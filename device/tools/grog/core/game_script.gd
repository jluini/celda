extends Resource

class_name GameScript

export (Array, Resource) var rooms

# TODO check these fields

export (Array, Resource) var actors
export (Resource) var inventory_items_scene
export (String) var default_action

var _valid = false

func get_key():
	return get_name()

func get_rooms():
	return rooms

func get_actors():
	return actors

func is_valid():
	return _valid

func prepare(compiler) -> Dictionary:
	if _valid:
		return { result = false, message = "Already prepared" }
	
	var ret = _prepare(compiler)
	_valid = ret.result
	return ret
	
func has_routine(headers: Array) -> bool:
	if not is_valid():
		print("Not valid")
		return false
	
	return _has_routine(headers)

func get_routine(headers: Array):
	if not is_valid():
		print("Not valid")
		return null
	
	return _get_routine(headers)

func get_sequence_with_parameter(_headers: Array, _param):
	print("Not implemented")
	return null

# abstract methods

func _get_routine(_headers: Array):
	print("Override _get_routine")
	return null
	
func _has_routine(_headers: Array) -> bool:
	print("Override _has_routine")
	return false
	
func _prepare(_compiler) -> Dictionary:
	return { result = false, message = "Override _prepare" }