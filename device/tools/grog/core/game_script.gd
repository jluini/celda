extends Resource

class_name GameScript

export (Dictionary) var rooms

export (PackedScene) var player

export (PackedScene) var inventory_items_scene

export (String) var default_action

export (Color) var default_color = Color.whitesmoke

export (Array, String) var stages = ["default"]

var _valid = false

func get_short_name() -> String:
	return get_name() # it returns the 'resource_name' property from Resource

func get_rooms() -> Dictionary:
	return rooms

func get_stages() -> Array:
	return stages

func is_valid() -> bool:
	return _valid

func prepare(compiler) -> Dictionary:
	if _valid:
		return { valid = false, message = "Already prepared" }
	
	var ret = _prepare(compiler)
	_valid = ret.valid
	return ret
	
func get_routine(headers: Array, tool_parameter: String) -> Resource:
	if not is_valid():
		print("Not valid")
		return null
	
	return _get_routine(headers, tool_parameter)

func get_sequence_with_parameter(_headers: Array, _param):
	print("Not implemented")
	return null

func get_item_actions(item) -> Array:
	return _get_item_actions(item.get_key())

# abstract methods

func _get_routine(_headers: Array, _tool_parameter: String) -> Resource:
	print("Override _get_routine")
	return null
	
func _prepare(_compiler) -> Dictionary:
	return { valid = false, message = "Override _prepare" }

func _get_item_actions(_item_key: String) -> Array:
	print("Override _get_item_actions")
	return []
