extends Node

export (PackedScene) var item_scene

func add_item(item: Node):
	var texture = item.texture
	var modulate = item.modulate
	
	var new_item_view = item_scene.instance()
	
	new_item_view.model = item
	
	new_item_view.get_node("image").texture = texture
	# TODO test this with masks
	new_item_view.get_node("image").modulate = modulate
	
	add_child_below_node(get_child(0), new_item_view)
	
func remove_item(item: Node):
	var cs = get_children()
	for i in range(1, cs.size()):
		var c = cs[i]
		if c.model == item:
			remove_child(c)
			return
	
	print("Item to remove not found!")

func get_item_at(position: Vector2) -> Node:
	var cs = get_children()
	for i in range(1, cs.size()):
		var c = cs[i]
		var rect: Rect2 = c.get_global_rect()
		if rect.has_point(position):
			return c
	
	return null
