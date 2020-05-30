extends Reference

class_name InventoryItemInstance

var _model: Node
var _instance_number: int = -1

var _key: String
var _id: String

func _init(model: Node, instance_number: int):
	_model = model
	_instance_number = _instance_number
	
	_key = model.get_key()
	_id = Grog.get_item_id(_key, instance_number)

func get_key() -> String:
	return _key

func get_id() -> String:
	return _id

func get_texture() -> Texture:
	return _model.get_texture()
