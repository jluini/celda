extends Node

export (PackedScene) var item_scene

export (int) var previous_children = 0
export (int) var later_children = 0

var _items: Array

func _ready():
	_items = []
	_validate_number_of_children()

func add_item(item_model: Object):
	var new_item_view = item_scene.instance()
	
	# TODO what is this for?
	new_item_view.set_model(item_model)
	
	_validate_number_of_children()
	
	var new_item_index = get_child_count() - later_children
	
	_add_child_at_index(new_item_index, new_item_view)
	_items.append(new_item_view)
	
func _add_child_at_index(index: int, child: Node) -> void:
	add_child(child)
	move_child(child, index)

func remove_item(item: Node):
	var cs = get_children()
	for i in range(1, cs.size()):
		var c = cs[i]
		if c.model == item:
			remove_child(c)
			return
	
	print("Item to remove not found!")

func get_item_at(position: Vector2) -> Node:
	for i in range(_items.size()):
		var c = _items[i]
		if c.has_node("item_box"):
			var f = c.get_node("item_box")
			var rect: Rect2 = f.get_global_rect()
			if rect.has_point(position):
				return c
		else:
			print("no box")
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
