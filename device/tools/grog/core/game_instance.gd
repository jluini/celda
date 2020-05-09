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

# game state

var symbols = SymbolTable.new([
	"player",
	"global_variable",
	"scene_item",
	"inventory_item",
	"inventory_item_instance",
])

var current_room: Node = null
var current_player: Node = null
var loaded_scene_items = {}

# constants

const _instant_termination = { termination = "instant" }

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
	
	while(true):
		_current_pointer += 1
		
		if _current_pointer < num_statements:
			var next_statement: Dictionary = statements[_current_pointer]
			
			if next_statement.type == "command":
				
				var result = _run_command(next_statement)
				
				match result.termination:
					"skip":
						_skip_enabled = true
						
						return true
						
					"instant":
						pass
						
					_:
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
	
	var output = self # TODO
	
	if not output.has_method(method_name):
		_log_error("execution target has no method '%s'" % method_name)
		return _instant_termination
	
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

func _command_load_room(room_name: String) -> Dictionary:
	# TODO validate state? same for all commands
	
	var room_resource = _get_room_resource(room_name)
	if not room_resource:
		_game_error("no room '%s'" % room_name)
		return _instant_termination
	
	#if not room_resource.get_target():
	#	print("No target scene in room resource '%s'" % room_name)
	#	return _instant_termination
	
	var room = room_resource.get_target().instance()
	
	if not room:
		_log_error("couldn't load room '%s'" % room_name)
		return _instant_termination
	
	var theres_and_old_room = current_room != null
	
	if theres_and_old_room:
		assert(false)
		# TODO implement
		# lower the curtain and load room afterwards
		
		return _instant_termination
	
	# detaches player from previous room
	if current_room and current_player:
		current_room.remove_child(current_player)
	
	if current_room:
		for item_key in loaded_scene_items:
			var item_symbol = symbols.get_symbol(item_key)
			
			assert(item_symbol.type == "scene_item")
			assert(item_symbol.loaded)
			
			if not item_symbol.disabled:
				# then is loaded, so tell the client to disable it
				_game_event("item_disabled", [item_symbol.target])
			
			item_symbol.loaded = false
		
		loaded_scene_items = {}
		
		_room_parent.remove_child(current_room)
		current_room.queue_free()
		current_room = null
	
	current_room = room
	
	if current_player:
		room.add_child(current_player)
		current_player.teleport(room.get_default_player_position())
	else:
		_log_warning("playing with no player")
	
	# care: items are not _ready yet
	
	for item in room.get_items():
		var item_key = item.get_key()
		
		if not item_key:
			_game_error("item with empty key in room '%s'" % room.get_name())
			continue
		elif item_key in ["self", "tool", "if"]: # TODO better check
			_game_error("an item can't have '%s' as id" % item_key)
			continue
		elif loaded_scene_items.has(item_key):
			_game_error("duplicated scene item '%s'" % item_key)
			continue
		
		var item_symbol = _get_or_build_scene_item(item_key, "load")
		
		if not item_symbol:
			# type mismatch
			_game_error("scene item key '%s' was used as %s" % [item_key, symbols.get_symbol_type(item_key)])
			continue
		
		item_symbol.target = item
		
		# TODO any item initialization required?
		#item_symbol.target.init_item(environment.compiler)
		
		assert(not item_symbol.loaded)
		item_symbol.loaded = true
		loaded_scene_items[item_key] = item
		
		if item_symbol.disabled:
			item.disable()
		else:
			if item.has_node("animation"):
				item.get_node("animation").play(item_symbol.animation)
			_game_event("item_enabled", [item])
	
	_room_parent.add_child(room) # _ready is called here for room and its items
	
	_game_event("room_loaded", [room]) # TODO parameter is not necessary
	
	return _instant_termination

func _command_set(var_name: String, new_value_expression) -> Dictionary:
	var new_value = new_value_expression.evaluate(self)
	
	_log("setting global '%s' to '%s' (type %s, class %s)" % [var_name, new_value, Grog._typestr(new_value), new_value.get_class() if typeof(new_value) == TYPE_OBJECT else "-"])
	
	var symbol = symbols.get_symbol_of_types(var_name, ["global_variable"], false)
	
	if symbol == null:
		# it's absent
		symbols.add_symbol(var_name, "global_variable", new_value)
	elif not symbol.type:
		# type mismatch
		pass
	else:
		# already present
		symbol.target = new_value
	
	# TODO is this a game event?
	_game_event("variable_set", [var_name, new_value])
	
	return _instant_termination

func _command_say(item_id: String, speech_token: Dictionary, opts: Dictionary) -> Dictionary:
	var speech = speech_token.expression.evaluate(self)
	
	if typeof(speech) != TYPE_STRING:
		_game_warning("saying not string: %s" % Grog._typestr(speech))
		speech = str(speech)
	
	if speech_token.type != Grog.TokenType.Quote:
		speech = tr(speech)
	
	var item = null
	
	if item_id:
		var item_symbol = symbols.get_symbol_of_types(item_id, ["player", "scene_item"], true) 
		
		if not item_symbol.type:
			# absent
			_game_warning("say: no item '%s'" % item_id)
			return _instant_termination
		
		# updates item_id (maybe it was 'self' or another alias)
		assert("symbol_name" in item_symbol)
		item_id = item_symbol.symbol_name
		
		if item_symbol.type == "scene_item":
			if not item_symbol.loaded:
				_game_warning("item '%s' can't speak: it's not loaded" % item_id)
				return _instant_termination
			elif item_symbol.disabled:
				_game_warning("item '%s' can't speak: it's disabled" % item_id)
				return _instant_termination
		
		item = item_symbol.target
	
	# else item will be null (it's a 'global' say)
	
	var duration: float = opts.get("duration", 2.0) # TODO harcoded default say duration
	var is_skippable = opts.get("skippable", true)  # TODO harcoded default say skippable
	
	_game_event("say", [item, speech, duration, is_skippable])
	
	return {
		termination = "skip"
	}

func _command_enable(item_key: String) -> Dictionary:
	var item_symbol = _get_or_build_scene_item(item_key, "enable")
	
	if not item_symbol:
		return _instant_termination
	
	item_key = item_symbol.symbol_name
	
	if not item_symbol.disabled:
		_game_warning("item '%s' is already enabled" % item_key)
		return _instant_termination
	
	item_symbol.disabled = false

	if item_symbol.loaded:
		var item = item_symbol.target
		assert(item == loaded_scene_items[item_key])

		item.enable()
		_game_event("item_enabled", [item])

	return _instant_termination
	
func _command_disable(item_key: String) -> Dictionary:
	var item_symbol = _get_or_build_scene_item(item_key, "disable")
	
	if not item_symbol:
		return _instant_termination
	
	item_key = item_symbol.symbol_name
	
	if item_symbol.disabled:
		_game_warning("item '%s' is already disabled" % item_key)
		return _instant_termination
	
	item_symbol.disabled = true

	if item_symbol.loaded:
		var item = item_symbol.target
		assert(item == loaded_scene_items[item_key])

		item.disable()
		_game_event("item_disabled", [item])

	return _instant_termination

func _command_curtain_up():
	_game_event("curtain_up")
	
	return _instant_termination

### command utils

# Returns the symbol for a scene item (or builds it if not created yet)
# Only returns null in case of type mismatch (symbol exists but its type doesn't match)
# Note that if item_id is 'self' or another alias you should correct it to match symbol.symbol_name
func _get_or_build_scene_item(item_key: String, debug_action_name: String):
	var symbol = symbols.get_symbol_of_types(item_key, ["scene_item"], false)
	if symbol == null:
		# absent
		symbol = symbols.add_symbol(item_key, "scene_item", null)
		symbol.loaded = false
		symbol.disabled = false
		symbol.animation = "default"
		
		return symbol
		
	elif not symbol.type:
		# type mismatch
		_game_warning("can't %s '%s'; is %s instead of scene_item" % [debug_action_name, item_key, symbols.get_symbol_type(item_key)])
		return null
		
	else:
		# already present
		return symbol

func _get_room_resource(room_name):
	return _get_resource_in(_game_script.get_rooms(), room_name)

static func _get_resource_in(list, elem_name):
	for i in range(list.size()):
		var elem = list[i]
		
		if elem.get_name() == elem_name:
			return elem
	
	return null

### client requests

func start_game_request(room_parent: Node) -> bool:
	if not _validate_game_state("start_game_request", GameState.Prepared):
		return false
	_game_state = GameState.Prepared
	
	_log("start_game_request(%s)" % room_parent)

	_room_parent = room_parent
	
	current_player = null # TODO player
	
	var init_routine = _get_routine(["main", "init"])
	
	if not init_routine:
		_log_error("init routine not found")
		return false
	
	if not _run_routine(init_routine):
		_log_error("can't run init routine")
		return false
	
	_game_event("game_started", [current_player])
	
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

func interact_request(_item, _trigger_name: String):
	_log_warning("TODO implement interact_request")
	
# client queries

func is_navigable(_world_position) -> bool:
	_log_warning("TODO implement is_navigable")
	return false

func get_default_color():
	return _game_script.default_color

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

func _game_warning(message: String, level = 0):
	_server._log_warning(message, _game_script.get_short_name(), level)
func _game_error(message: String, level = 0):
	_server._log_error(message, _game_script.get_short_name(), level)
