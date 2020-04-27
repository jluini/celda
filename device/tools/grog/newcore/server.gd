extends Node

var environment
var _game = null

func init(env, game):
	environment = env
	#assert(game.is_compiled() and game.is_valid())
	assert(game.is_valid())
	_game = game

func is_navigable(_world_position):
	print("TODO implement is_navigable")
	return false
