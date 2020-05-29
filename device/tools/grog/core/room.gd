extends Node

export (NodePath) var navigation_path = "navigation"

func get_navigation():
	return get_node_if_present(navigation_path)

func get_node_if_present(node_path):
	if not node_path:
		return null
	
	if not has_node(node_path):
		print("No has node with path '%s'" % node_path)
		return null
	
	return get_node(node_path)

func get_items():
	# TODO do some check?
	return $items.get_children()
