extends Node

var _game = null

func init(game):
	#assert(game.is_compiled() and game.is_valid())
	assert(game.is_valid())
	_game = game

func is_navigable(_world_position):
	print("TODO implement is_navigable")
	return false
