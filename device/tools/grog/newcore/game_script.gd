extends Resource

class_name GameScript

export (Array, Resource) var rooms

var _valid = false

func get_key():
	return get_name()

func get_rooms():
	return rooms

func is_valid():
	return _valid

func prepare(compiler) -> Dictionary:
	if _valid:
		return { result = false, msg = "Already prepared" }
	
	var ret = _prepare(compiler)
	_valid = ret.result
	return ret
	
func get_sequence():
	if not is_valid():
		print("Not valid")
		return null
	
	return _get_sequence()

func _get_sequence():
	print("Override _get_sequence")
	return null
	
func _prepare(_compiler) -> Dictionary:
	return { result = false, msg = "Override _prepare" }
