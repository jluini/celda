
extends Node

var _holders = []
var _items = []

func _ready():
	for c in get_children():
		if c.get_name().begins_with("elem"):
			_holders.append(c)

func clear():
	for i in range(_holders.size()):
		_holders[i].get_node("image").texture = null
	_items = []

func add_item(item_resource):
	var holder = next_holder()
	
	if item_resource and item_resource.texture:
		holder.get_node("image").texture = item_resource.texture
	
	_items.append(item_resource)

func next_holder():
	var index = _items.size()
	if index < _holders.size():
		return _holders[index]
	else:
		print("Implement this!")
	
