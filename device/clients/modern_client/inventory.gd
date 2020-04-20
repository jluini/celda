extends Node

export (PackedScene) var item_scene

func add_item(item: Node):
	var texture = item.texture
	var modulate = item.modulate
	
	var new_item_view = item_scene.instance()
	
	new_item_view.model = item
	
	var image = new_item_view.get_node("item_box/image")
	
	image.texture = texture
	# TODO test this with masks
	image.modulate = modulate
	
	var count = get_child_count()
	if count <= 1:
		add_child(new_item_view)
	else:
		add_child_below_node(get_child(count - 2), new_item_view)
	
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
		if c.has_node("item_box"):
			var f = c.get_node("item_box")
			var rect: Rect2 = f.get_global_rect()
			if rect.has_point(position):
				return c
	
	return null
