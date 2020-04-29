extends Node

var _server
var _game_script = null

func init(server, game_script):
	_server = server
	#assert(game.is_compiled() and game.is_valid())
	assert(game_script.is_valid())
	_game_script = game_script

func is_navigable(_world_position):
	print("TODO implement is_navigable")
	return false
