extends Node

export (NodePath) var default_player_position_path = "positions/default"
export (NodePath) var navigation_path = "navigation"

func get_default_player_position() -> Vector2:
	var default_player_position_holder = get_node_if_present(default_player_position_path)
	
	if default_player_position_holder:
		return default_player_position_holder.position
	else:
		return Vector2()

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
