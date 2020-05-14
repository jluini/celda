extends Resource

class_name SavedGame

export (bool) var is_ready
export (Array, String) var routine_headers
export (Array, int) var routine_stack

export (String) var current_room

export (Vector2) var player_position
# TODO player orientation

export (Array, Dictionary) var global_variables
export (Array, Dictionary) var scene_items

# TODO inventory items
# TODO aliases?

# TODO curtain state


func init():
	pass

func read_from(game_instance):
	is_ready = game_instance.is_ready()
	
	if not is_ready:
		routine_headers = game_instance.get_current_headers()
		routine_stack = game_instance.get_current_stack()
	
	current_room = game_instance.get_current_room_name()
	
	player_position = game_instance.get_player_position()
	# TODO player orientation
	
	global_variables = game_instance.get_global_variables()
	scene_items = game_instance.get_scene_items()
	
	# TODO inventory items
	# TODO aliases?
	
	# TODO curtain state
