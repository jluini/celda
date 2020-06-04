extends Node

export (PackedScene) var item_scene

export (int) var previous_children = 0
export (int) var later_children = 0

var _items: Array

func _ready():
	_items = []
	_validate_number_of_children()

func add_item(item_instance: Object):
	var new_item_view = item_scene.instance()
	
	# TODO what is this for?
	new_item_view.set_item(item_instance)
	
	_validate_number_of_children()
	
	var new_item_index = get_child_count() - later_children
	
	_add_child_at_index(new_item_index, new_item_view)
	_items.append(new_item_view)
	
func _add_child_at_index(index: int, child: Node) -> void:
	add_child(child)
	move_child(child, index)

func remove_item(item_instance):
	# TODO improve this...
	_validate_number_of_children()
	for index in range(_items.size()):
		var item_view = _items[index]
		
		if item_view.get_item_instance() == item_instance:
			remove_child(item_view)
			item_view.queue_free()
			_items.remove(index)
			return
	
	print("Item to remove not found!")

func get_item_at(position: Vector2) -> Node:
	for i in range(_items.size()):
		var view = _items[i]
		if view.has_node("item_box"):
			var box = view.get_node("item_box")
			var rect: Rect2 = box.get_global_rect()
			if rect.has_point(position):
				return view
		else:
			print("no box")
	return null

func get_view(item_instance) -> Node:
	for i in range(_items.size()):
		var view = _items[i]
		if view.get_item_instance() == item_instance:
			return view
	
	return null

func clear():
	_validate_number_of_children()
	
	var number_of_fixed_children = _get_number_of_fixed_children()
	
	while get_child_count() > number_of_fixed_children:
		remove_child(get_child(previous_children))
	
	_items = []
	
func _get_number_of_fixed_children():
	return previous_children + later_children

func _validate_number_of_children():
	var expected_number_of_children = _get_number_of_fixed_children() + _items.size()
	
	if get_child_count() != expected_number_of_children:
		push_warning("expecting %s children but having %s" % [expected_number_of_children, get_child_count()])
