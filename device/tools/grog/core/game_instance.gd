extends Node

signal game_event

# State

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


# Running routines

var _current_routine = null

var _current_pointer: int

# Termination
var _skip_enabled: bool = false


# current room node is placed here;
# players are placed inside current room
var _room_parent : Node

func init(server, game_script) -> bool:
	if not _validate_game_state("init", GameState.NotInitialized):
		return false
	
	_server = server
	_game_script = game_script
	
	# TODO improve
	assert(_game_script.is_valid())
	
	_game_state = GameState.Prepared
	
	return true

# private

func _run_routine(routine):
	if not _validate_interaction_state("_run_routine", InteractionState.Nothing):
		return false
	
	_interaction_state = InteractionState.Running
	
	_current_routine = routine
	
	_current_pointer = -1
	
	_advance()
	
	return true

# runs until...
#    - routine is over (returning false)
#    - a timed command started (returning true)
func _advance() -> bool:
	var statements: Array = _current_routine.statements
	var num_statements = statements.size()
	
	assert(_current_pointer < num_statements)
	
	_current_pointer += 1
	
	if _current_pointer < num_statements:
		var next_statement: Dictionary = statements[_current_pointer]
		
		if next_statement.type == "command":
			
			var result = _run_command(next_statement)
			
			if result.termination == "skip":
				_skip_enabled = true
				
				return true
			else:
				assert(false) # TODO
			
		else:
			assert(false) # TODO
		
	else:
		# routine is over
		
		# TODO
		
		return false
	
	# unreachable
	assert(false)
	return false

func _run_command(command: Dictionary):
	if not command.has("command_name") or not command.has("params"):
		_log_error("invalid command %s" % _task_str(command))
		assert(false) # TODO what to do after this error?
		return
		
	var cmd = command.command_name
	var params = command.params
	
	var method_name = "_command_" + cmd
	
	var output = self
	
	if not output.has_method(method_name):
		_log_error("execution target has no method '%s'" % method_name)
		assert(false) # TODO what to do after this error?
		return
	
	var command_result = output.callv(method_name, params)
	
	return command_result

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

### commands

func _command_say(item_id: String, speech_token: Dictionary, opts: Dictionary) -> Dictionary:
	var speech = speech_token.expression.evaluate(self)
	
	if typeof(speech) != TYPE_STRING:
		_log_warning("saying not string: %s" % Grog._typestr(speech))
		speech = str(speech)
	
	if speech_token.type != Grog.TokenType.Quote:
		speech = tr(speech)
	
	print("saying %s" % speech)
	
	return {
		termination = "skip"
	}


### client requests

func start_game_request(room_parent: Node) -> bool:
	if not _validate_game_state("start_game_request", GameState.Prepared):
		return false
	_game_state = GameState.Prepared
	
	_log("start_game_request(%s)" % room_parent)

	_room_parent = room_parent
	
	var player = null # TODO
	
	var init_routine = _get_routine(["main", "init"])
	
	if not init_routine:
		_log_error("init routine not found")
		return false
	
	if not _run_routine(init_routine):
		_log_error("can't run init routine")
		return false
	
	_game_event("game_started", [player])
	
	_game_state = GameState.Playing
	
	return true

func skip_request() -> bool:
	if _skip_enabled: # and not _skip_requested:
		_log("skip accepted")
		#_skip_requested = true
		_skip_enabled = false
		
		_advance()
		
		return true
	
	else:
		
		return false

# client queries

func is_navigable(_world_position) -> bool:
	_log_warning("TODO implement is_navigable")
	return false

# Validation

func _validate_game_state(func_name: String, _expected_state) -> bool:
	var valid_state = _game_state == _expected_state
	
	if not valid_state:
		_log_invalid_game_state(func_name)
	
	return valid_state

func _validate_interaction_state(func_name: String, _expected_state) -> bool:
	var valid_state = _interaction_state == _expected_state
	
	if not valid_state:
		_log_invalid_interaction_state(func_name)
	
	return valid_state



# Static utils

static func _task_str(task: Dictionary):
	var cmd: String = task.command
	return "[%s]" % cmd.to_upper()

static func _state_str(game_state: int) -> String:
	var keys: Array = GameState.keys()
	if game_state < 0 or game_state >= keys.size():
		return "???"
	
	return keys[game_state]

static func _interaction_state_str(interaction_state: int) -> String:
	var keys: Array = InteractionState.keys()
	if interaction_state < 0 or interaction_state >= keys.size():
		return "???"
	
	return keys[interaction_state]


# Local logging shortcuts

func _log_invalid_game_state(func_name: String):
	_log_error("can't call '%s' while game state is %s" % [func_name, _state_str(_game_state)])
func _log_invalid_interaction_state(func_name: String):
	_log_error("can't call '%s' while interaction state is %s" % [func_name, _interaction_state_str(_interaction_state)])

func _log(message: String, level = 0):
	_server._log(message, "game-instance", level)
func _log_warning(message: String, level = 0):
	_server._log_warning(message, "game-instance", level)
func _log_error(message: String, level = 0):
	_server._log_error(message, "game-instance", level)

