extends Resource

class_name GameScript

export (Dictionary) var rooms

export (Resource) var player

export (Resource) var inventory_items_scene
export (String) var default_action

export (Color) var default_color = Color.whitesmoke

var _valid = false

func get_short_name():
	return get_name() # it returns the Resource name

func get_rooms():
	return rooms

func is_valid():
	return _valid

func prepare(compiler) -> Dictionary:
	if _valid:
		return { valid = false, message = "Already prepared" }
	
	var ret = _prepare(compiler)
	_valid = ret.valid
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
	return { valid = false, message = "Override _prepare" }
