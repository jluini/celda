extends Node

signal game_event


enum GameState {
	NotInitialized,
	Prepared,
	Playing
}
var _game_state = GameState.NotInitialized

enum InteractionState {
	Nothing,
	Running,
	Walking
}
var _interaction_state = InteractionState.Nothing

var _server
var _game_script

# current room node is placed here;
# players are placed inside current room
var _room_parent : Node

func init(server, game_script) -> bool:
	if not _validate_game_state("init", GameState.NotInitialized):
		return false
	
	_server = server
	assert(game_script.is_valid())
	_game_script = game_script
	
	return true

func update(_delta):
	pass

### client requests

func start_game_request(room_parent: Node) -> bool:
	_log("start_game_request(%s)" % room_parent)

	_room_parent = room_parent
	
	var player = null # TODO
	
	var init_routine = _get_routine(["main", "init"])
	
	
	_game_event("game_started", [player])
	
	return true

# sends events to client
func _game_event(event_name: String, args: Array = []):
	#_log("SERVER EVENT '%s'" % event_name)
	emit_signal("game_event", event_name, args)

func _get_routine(headers: Array):
	if _game_script.has_routine(headers):
		return _game_script.get_routine(headers)
	else:
		# TODO warning or error?
		_log_warning("routine '%s' not found" % str(headers))
		return null


# Validation

func _validate_game_state(func_name: String, _expected_state) -> bool:
	var valid_state = _game_state == _expected_state
	
	if not valid_state:
		_log_invalid_game_state(func_name)
	
	return valid_state

func _log_invalid_game_state(func_name: String):
	_log_error("can't call '%s' while state is %s" % [func_name, _state_str(_game_state)])


# Static utils

static func _state_str(game_state: int) -> String:
	var keys: Array = GameState.keys()
	if not game_state < 0 or game_state >= keys.size():
		return "???"
	
	return keys[game_state]

# Local logging shortcuts

func _log(message: String, level = 0):
	_server._log(message, "game-instance", level)
func _log_warning(message: String, level = 0):
	_server._log_warning(message, "game-instance", level)
func _log_error(message: String, level = 0):
	_server._log_error(message, "game-instance", level)




































































































































func is_navigable(_world_position) -> bool:
	_log_warning("TODO implement is_navigable")
	return false


