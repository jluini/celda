extends Node

signal game_event

var _server
var _game_script

# current room node is placed here;
# players are placed inside current room
var _room_parent : Node

func init(server, game_script) -> bool:
	_server = server
	assert(game_script.is_valid())
	_game_script = game_script
	
	return true

func update(_delta):
	pass

func is_navigable(_world_position) -> bool:
	print("TODO implement is_navigable")
	return false


### client requests

func start_game_request(room_parent: Node) -> bool:
	_room_parent = room_parent
	
	# TODO
	
	var player = null # TODO
	_game_event("game_started", [player])
	return true


# sends events to client
func _game_event(event_name: String, args: Array = []):
	#print("SERVER EVENT '%s'" % event_name)
	emit_signal("game_event", event_name, args)

