extends Node

signal game_event

var _server
var _game_script

func init(server, game_script):
	_server = server
	assert(game_script.is_valid())
	_game_script = game_script
	
	# TODO remove
	var player = 4 # sorry
	_game_event("game_started", [player])

func update(_delta):
	pass

func is_navigable(_world_position):
	print("TODO implement is_navigable")
	return false

func start_game_request(_room_parent: Node) -> bool:
	print("TODO: implement start_game_request")
	return true

# sends events to client
func _game_event(event_name: String, args: Array = []):
	#print("SERVER EVENT '%s'" % event_name)
	emit_signal("game_event", event_name, args)

