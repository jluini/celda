extends Node

signal game_event

# State

enum GameState {
	NotInitialized,
	Prepared,
	Playing
}
var _game_state : int = GameState.NotInitialized

enum InteractionState {
	None,
	Ready,
	Running
}
var _interaction_state : int = InteractionState.None

var _server # grog server node
var _game_script # GameScript resource

var _starting_from_saved_game: bool
var _saved_player_position: Vector2

var _is_paused: bool = false

# Running routines

var _current_routine_headers: Array
var _current_routine: Resource = null
var _current_pointers: Array = []
var _current_context: Dictionary = {}

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
var _current_room_name: String = ""
var current_player: Node2D = null
var loaded_scene_items = {}

# walking state

enum WalkingReason {
	# not walking
	None,
	
	# walking by script indication (auto-walk)
	Automatic,
	
	# walking by client go-to request (standard-walk)
	GoingToPosition,
	
	# walking by client interact request (pre-walk)
	GoingToItem
}

var _walking_reason : int = WalkingReason.None
var _walking_time: float # seconds since current segment started
var _walking_path: PoolVector2Array
var _walking_subject: Node2D
var _walking_direction: Vector2
var _walking_distance2: float

# constants

const _instant_termination = { termination = "instant" }

###

func init_game(server, game_script: Resource, saved_game: Resource, initial_stage: int) -> Dictionary:
	if not _validate_game_state("init_game", GameState.NotInitialized):
		return { valid = false, message = "invalid state" }
	
	_server = server
	_game_script = game_script
	
	# TODO improve
	assert(_game_script.is_valid())
	
	var player_resource = _game_script.player
	current_player = player_resource.instance()
	symbols.add_symbol("you", "player", current_player)
	
	var ii_scene: Node = game_script.inventory_items_scene.instance()
	
	for ii_model in ii_scene.get_children():
		var key: String = ii_model.get_key()
		
		if symbols.has_symbol(key):
			_game_error("duplicated inventory item id '%s'" % key)
			continue
		
		var new_symbol = symbols.add_symbol(key, "inventory_item", ii_model)
		new_symbol.amount = 0
		new_symbol.last_instance_number = 0
		#new_symbol.instances = []
		
	if saved_game != null:
		_starting_from_saved_game = true
		var read_result = _read_saved_game(saved_game)
		
		if not read_result.valid:
			return read_result
		
		if initial_stage:
			_log_warning("ignoring initial_stage '%s' because it's a saved game" % initial_stage)
		
	else:
		_starting_from_saved_game = false
		symbols.add_symbol("stage", "global_variable", initial_stage)
	
	_game_state = GameState.Prepared
	
	return { valid = true }

func release():
	_log_debug("releasing game")
	
	_set_tree_paused(false)
	
	if symbols:
		symbols.free()
	else:
		_log_warning("symbols not initialized")
	
	if current_player:
		_log_debug("deleting player")
		
		if current_player.is_inside_tree():
			if not current_room:
				_log_warning("player is in tree but no room")
			elif current_room != current_player.get_parent():
				_log_warning("player is in tree but outside current room")
				
			current_player.get_parent().remove_child(current_player)
		else:
			_log_debug("deleting player outside of scene tree")
		
		current_player.queue_free()
	
	if current_room:
		_log_debug("deleting room")
		
		if current_room.is_inside_tree():
			current_room.get_parent().remove_child(current_room)
		else:
			_log_warning("deleting room outside of scene tree")
		
		current_room.queue_free()
	
	_log_debug("game release finished")

func get_value(var_name: String):
	var symbol = symbols.get_symbol(var_name)
	
	if symbol == null:
		# absent
		_game_error("global variable or symbol '%s' not found" % var_name)
		return 0 # absent symbol defaults to zero
	
	match symbol.type:
		"global_variable":
			return symbol.target
		
#		"inventory_item":
#			return symbol.amount
#
#		"inventory_item_instance":
#			return symbol.target.get_key()
#
#		"scene_item":
#			if symbol.disabled:
#				return "disabled"
#			else:
#				return symbol.animation
		_:
			_game_warning("trying to dereference symbol '%s' of type '%s'" % [var_name, symbol.type])
			return false

func _ready():
	set_process(false)

func _process(delta: float) -> void:
	# if _process is called the player is walking, either in response to a client
	# request ("client walk") or by a routine statement ("auto walk")
	
	if _walking_reason == WalkingReason.None:
		_log_error("shouldn't be processing if not walking")
		set_process(false)
		return
	
	_walking_time += delta
	
	var step_distance: float = _walking_subject.get_speed() * _walking_time
	var target_point: Vector2 = _walking_path[0] + step_distance * _walking_direction
	
	if pow(step_distance, 2) >= _walking_distance2:
		# current destination reached
		
		_walking_subject.teleport(_walking_path[1])
		_walking_path.remove(0)
		
		if _walking_path.size() < 2:
			# final destination reached
			set_process(false)
			_walking_subject.stop()
			
			match _walking_reason:
				WalkingReason.Automatic:
					if _interaction_state != InteractionState.Running:
						_log_error("unexpected interaction state '%s' when automatic walk is over" % _interaction_state_str())
						
					call_deferred("_advance")
				
				WalkingReason.GoingToPosition:
					pass
				
				WalkingReason.GoingToItem:
					_run_routine()
				
				_:
					assert(false)
			
			_walking_reason = WalkingReason.None
		else:
			_setup_walking_segment()
	else:
		_walking_subject.teleport(target_point)

# running

func _run_routine() -> void:
	symbols.set_context(_current_context)
	_interaction_state = InteractionState.Running
	call_deferred("_advance")

# runs until...
#    - routine is over (returning false)
#    - a timed command started (returning true)
func _advance(): # -> bool: # it returns a bool by I'm ignoring it currently
	if not _validate_game_state("_advance", GameState.Playing):
		return false
	if not _validate_interaction_state("_advance", InteractionState.Running):
		return false
	
	while(true):
		assert(_current_pointers.size() > 0)
		assert(_current_pointers.size() % 2 == 1)
		
		# warning-ignore:integer_division
		var num_levels: int = (_current_pointers.size() - 1) / 2
		
		var statements: Array = _current_routine.statements
		
		for lvl in range(num_levels):
			var lvl_pointer = _current_pointers[lvl * 2]
			var branch_pointer = _current_pointers[lvl * 2 + 1]
			var lvl_block = statements[lvl_pointer]
			var lvl_branch = lvl_block.branches[branch_pointer]
			
			statements = lvl_branch.statements
		
		assert(statements.size() > _current_pointers[-1])
		
		# advances to next statement
		_current_pointers[-1] += 1
		
		if _current_pointers[-1] >= statements.size():
			# this block is over
			
			if _current_pointers.size() == 1:
				# whole routine is over
				
				_current_routine = null
				_current_pointers = []
				_current_context = {}
				symbols.set_context(_current_context)
				_interaction_state = InteractionState.Ready
				
				return false
			else:
				assert(_current_pointers.size() > 2)
				_current_pointers.pop_back()
				_current_pointers.pop_back()
				
				continue
		
		# fetch next statement
		var next_statement: Dictionary = statements[_current_pointers[-1]]
		
		if next_statement.type == "command":
			var result = _run_command(next_statement)
			
			match result.termination:
				"skip":
					_skip_enabled = true
					return true
				
				"custom":
					return true
				
				"instant":
					pass
					
				_:
					_log_error("command '%s': invalid termination '%s'" % [next_statement.command_name, result.termination])
		
		elif next_statement.type == "if":
			var branches = next_statement.branches
			var branch_to_execute: int = -1
			var output = self # TODO
			
			for branch_index in range(branches.size()):
				var branch: Dictionary = branches[branch_index]
				var condition_result = branch.condition.evaluate(output)
				
				if typeof(condition_result) != TYPE_BOOL:
					_game_warning("evaluating not-bool as condition (%s)" % Grog._typestr(condition_result))
					condition_result = condition_result as bool
				
				if condition_result:
					branch_to_execute = branch_index
					break
			
			if branch_to_execute >= 0:
				_current_pointers.push_back(branch_to_execute)
				_current_pointers.push_back(-1)
			
		else:
			_log_error("invalid statement type '%s'" % next_statement.type)
	
	# unreachable
	assert(false)
	return false

func _run_command(command: Dictionary) -> Dictionary:
	if not command.has("command_name") or not command.has("params"):
		_log_error("invalid command %s" % _task_str(command))
		return _instant_termination
	
	var cmd = command.command_name
	var params = command.params
	
	var method_name = "_command_" + cmd
	
	var output = self # TODO
	
	if not output.has_method(method_name):
		_log_error("execution target has no method '%s'" % method_name)
		return _instant_termination
	
	# TODO check number of parameters
	
	var command_result = output.callv(method_name, params)
	
	if typeof(command_result) != TYPE_DICTIONARY:
		_log_error("invalid command result type (%s)" % Grog._typestr(command_result))
		return _instant_termination
	
	if not command_result.has("termination"):
		_log_error("invalid command result (no termination)")
		return _instant_termination
	
	return command_result

### commands

func _command_load_room(room_name: String) -> Dictionary:
	# TODO validate state? same for all commands
	
	var room_resource = _get_room_resource(room_name)
	if not room_resource:
		_game_error("no room '%s'" % room_name)
		return _instant_termination
	
	var room = room_resource.instance()
	
	# make room pausable
	room.pause_mode = PAUSE_MODE_STOP
	
	if not room:
		_log_error("couldn't load room '%s'" % room_name)
		
		# TODO should end whole routine instead of passing to next statement?
		return _instant_termination
	
	var theres_and_old_room = current_room != null
	
	if theres_and_old_room:
		# TODO lower the curtain
		
		# TODO duplicated code in release
		# detaches player from previous room
		if current_player and current_player.is_inside_tree():
			if current_room != current_player.get_parent():
				_log_warning("player is in tree but outside current room (loading room '%s')" % room_name)
			
			current_player.get_parent().remove_child(current_player)
		
		# unload loaded items
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
	
	_current_room_name = room_name
	current_room = room
	
	if current_player:
		# TODO adding player to room always
		room.add_child(current_player)
		
		current_player.set_room(room)
		
		# TODO ability to use another starting position
		# TODO set orientation aswell
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
		
		if not item_symbol: # (type mismatch, error was logged already)
			continue
		
		item_symbol.target = item
		
		assert(not item_symbol.loaded)
		item_symbol.loaded = true
		loaded_scene_items[item_key] = item
		
		if item_symbol.disabled:
			item.disable()
		else:
			# TODO improve animation/enabledness logic
			if item.has_node("animation"):
				item.get_node("animation").play(item_symbol.animation)
			_game_event("item_enabled", [item])
	
	_room_parent.add_child(room) # _ready is called here for room and its items
	
	_game_event("room_loaded", [room]) # TODO parameter is not necessary
	
	return _instant_termination

func _command_curtain_up():
	_game_event("curtain_up")
	
	return _instant_termination

func _command_set(var_name: String, new_value_expression) -> Dictionary:
	var new_value = new_value_expression.evaluate(self)
	
	#_log_debug("setting global '%s' to '%s' (type %s, class %s)" % [var_name, new_value, Grog._typestr(new_value), new_value.get_class() if typeof(new_value) == TYPE_OBJECT else "-"])
	
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
	return _change_enabledness(item_key, true)

func _command_disable(item_key: String) -> Dictionary:
	return _change_enabledness(item_key, false)

func _command_add(inv_key: String) -> Dictionary:
	var item_symbol = symbols.get_symbol_of_types(inv_key, ["inventory_item"], true)
	
	if not item_symbol.type:
		_game_error("no inventory_item '%s'" % inv_key)
		return _instant_termination
	
	item_symbol.amount += 1
	
	var new_instance_number: int = item_symbol.last_instance_number + 1
	item_symbol.last_instance_number = new_instance_number
	
	var new_symbol_id: String = Grog.get_item_id(inv_key, new_instance_number)
	
	var model: Node = item_symbol.target
	
	var new_instance := InventoryItemInstance.new(model, new_instance_number)
	
	assert(new_symbol_id == new_instance.get_id())
	
	# TODO actually another item could collide with this name
	
	symbols.add_symbol(new_symbol_id, "inventory_item_instance", new_instance)
	
	_game_event("item_added", [new_instance])
	
	return _instant_termination

func _command_remove(item_id: String) -> Dictionary:
	var instance_symbol = symbols.get_symbol_of_types(item_id, ["inventory_item_instance"], true)
	
	if not instance_symbol.type:
		_game_error("no inventory_item_instance '%s'" % item_id)
		return _instant_termination
	
	item_id = instance_symbol.symbol_name
	
	var key_and_number = Grog.get_item_key_and_number(item_id)
	
	if not key_and_number.valid:
		_log_error("invalid inventory item instance id '%s'" % item_id)
		return _instant_termination
	
	var model_symbol = symbols.get_symbol_of_types(key_and_number.item_key, ["inventory_item"], true)
	
	if not model_symbol.type:
		_log_error("inventory item instance '%s' has no associated model symbol")
		return _instant_termination
	
	model_symbol.amount -= 1
	
	var item_instance = instance_symbol.target
	
	# TODO instead, don't store inventory instances as symbols...
	instance_symbol.target = null
	
	_game_event("item_removed", [item_instance])
	
	return _instant_termination

func _command_teleport(item_id: String, target_node_name: String, opts: Dictionary) -> Dictionary:
	var player = _get_player(item_id)
	
	if not player:
		return _instant_termination
	
	var positioning = _get_target_positioning("teleport", target_node_name, opts)
	
	if positioning.valid:
		_teleport(player, positioning)
	# else error was logged already
	
	return _instant_termination

func _command_walk(item_id: String, target_node_name: String) -> Dictionary:
	var player: Node2D = _get_player(item_id)
	
	if not player:
		return _instant_termination
	
	var positioning = _get_target_positioning("walk", target_node_name, {})
	
	if not positioning.valid:
		return _instant_termination
	
	if not _start_walking(player, positioning.target_position, WalkingReason.Automatic):
		return _instant_termination
	
	return { termination = "custom" }


### command utils

# TODO this must be revised
# currently always returns the player so doesn't make much sense
func _get_player(item_id: String) -> Node:
	var item_symbol = symbols.get_symbol_of_types(item_id, ["player"], true)
	
	if not item_symbol.type:
		_game_warning("no player '%s'" % item_id)
		return null
	
	var ret = item_symbol.target

	assert(not not ret)
	assert(ret == current_player)
	
	return ret

func _get_target_positioning(verb: String, target_node_name: String, opts: Dictionary) -> Dictionary:
	var target_position: Vector2 # TODO this is coupled with two-dimensional geometry
	var set_angle: bool = false
	var target_angle: int
	
	if opts.has("angle"):
		var angle_option = opts["angle"]
		
		if typeof(angle_option) != TYPE_INT:
			_log_warning("angle is of type %s" % Grog._typestr(angle_option))
			angle_option = int(angle_option)
		
		set_angle = true
		target_angle = angle_option
	
	# tries to find a scene item first
	var to_node_symbol = symbols.get_symbol_of_types(target_node_name, ["scene_item"], false)
	
	if to_node_symbol == null:
		var position_node_name: String = "positions/" + target_node_name
		# absent; find a plain node then
		if not current_room.has_node(position_node_name):
			_game_warning("node '%s' not found" % position_node_name)
			return { valid = false }
		else:
			# target is a plain node
			var plain_node: Node2D = current_room.get_node(position_node_name)
			target_position = plain_node.position
	
	elif not to_node_symbol.type:
		# type mismatch
		_log_warning("can't %s to an object of type '%s'" % [verb, symbols.get_symbol_type(target_node_name)])
		return { valid = false }
	
	else:
		# scene item found
		if not to_node_symbol.loaded:
			_log_warning("%s: item '%s' is not in current room" % [verb, target_node_name])
			return { valid = false }
		elif to_node_symbol.disabled:
			_log_warning("%s: item '%s' is disabled" % [verb, target_node_name])
			return { valid = false }
		else:
			# target is a scene item
			var to_node = to_node_symbol.target
			target_position = to_node.get_interact_position()
			
			if not set_angle:
				# use interaction angle by default
				set_angle = true
				target_angle = to_node.get_interact_angle()
	
	return {
		valid = true,
		target_position = target_position,
		set_angle = set_angle,
		target_angle = target_angle
	}

func _change_enabledness(item_key: String, new_enabledness: bool) -> Dictionary:
	var verb = "enable" if new_enabledness else "disable"
	
	var item_symbol = _get_or_build_scene_item(item_key, verb)
	
	if not item_symbol: # (type mismatch, error was logged already)
		return _instant_termination
	
	# original item_key could be an alias like 'self', so we update it here
	# to match the actual key; otherwise this has no effect
	item_key = item_symbol.symbol_name
	
	var new_disabledness = not new_enabledness
	
	if new_disabledness == item_symbol.disabled:
		_game_warning("item '%s' is already %sd" % [item_key, verb])
		return _instant_termination
	
	item_symbol.disabled = new_disabledness
	
	if item_symbol.loaded:
		var item = item_symbol.target
		assert(item == loaded_scene_items[item_key])
		
		if new_enabledness:
			item.enable()
			_game_event("item_enabled", [item])
		else:
			item.disable()
			_game_event("item_disabled", [item])

	return _instant_termination

func _teleport(item: Node, positioning: Dictionary) -> void:
	item.teleport(positioning.target_position)
	
	if positioning.set_angle:
		item.set_angle(positioning.target_angle)

# used for command 'walk' and for client requests (go_to/interact)
func _start_walking(subject: Node2D, original_target_position: Vector2, reason: int) -> bool:
	var nav : Navigation2D = current_room.get_navigation()
	
	if not nav:
		_game_warning("room has no navigation polygon")
		return false
	
	var origin_position = subject.position
	var target_position: Vector2 = nav.get_closest_point(original_target_position)
	
	# TODO don't walk if we are close enough to destination
	
	var path: PoolVector2Array = nav.get_simple_path(origin_position, target_position)
	
	if path.size() < 2:
		_log_error("path is too short (length = %s)" % path.size())
		return false
	
	if reason == WalkingReason.None:
		_log_error("not a good reason to walk")
		return false
	
	_walking_path = path
	_walking_subject = subject
	_walking_reason = reason
	_setup_walking_segment()
	
	set_process(true)
	
	return true

func _setup_walking_segment():
	assert(_walking_path.size() >= 2)
	
	_walking_time = 0.0
	var displacement = _walking_path[1] - _walking_path[0]
	_walking_distance2 = displacement.length_squared()
	_walking_direction = displacement.normalized()
	var angle = _get_degrees(_walking_direction)
	_walking_subject.walk(angle)

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


### client requests

func start_game_request(room_parent: Node) -> bool:
	if not _validate_game_state("start_game_request", GameState.Prepared):
		return false
	
	_room_parent = room_parent
	_game_state = GameState.Playing
	
	if _starting_from_saved_game:
		if _current_room_name:
			# TODO use another function name for this
			# warning-ignore:return_value_discarded
			_command_load_room(_current_room_name)
			
			if not current_room:
				_log_error("loading saved '%s' room failed" % _current_room_name)
				return false
			
			if current_player:
				current_player.teleport(_saved_player_position)
				# TODO player orientation
			else:
				_log_warning("loading game but no current player")
		else:
			_log_warning("loading game with no current room")
		
	else:
		if not _validate_interaction_state("start_game_request", InteractionState.None):
			return false
		
		_interaction_state = InteractionState.Ready
		
		var initial_routine_found: bool = _fetch_routine(["main", "init"], {})
		
		if not initial_routine_found:
			_game_error("initial routine not found")
			return false
		
		_run_routine()
	
	# this doesn't do anything yet
	_game_event("game_started", [current_player])
	
	# TODO this should be saved instead
	if _starting_from_saved_game:
		_game_event("curtain_up")
		
		# TODO save and recover last saying and timer
	
	return true

func skip_request() -> bool:
	if _skip_enabled: # and not _skip_requested:
		_log_debug("skip accepted")
		#_skip_requested = true
		_skip_enabled = false
		
		call_deferred("_advance")
		
		return true
	
	else:
		
		return false

func go_to_request(target_position: Vector2) -> bool:
	if not _validate_game_state("go_to_request", GameState.Playing):
		return false
	if not _validate_interaction_state("go_to_request", InteractionState.Ready):
		return false
	
	if not current_player:
		_log_warning("go_to_request: no player")
		return false
	
	if not _start_walking(current_player, target_position, WalkingReason.GoingToPosition):
		return false
	
	return true

func interact_request(item, trigger_name: String) -> bool:
	if not _validate_game_state("interact_request", GameState.Playing):
		return false
	if not _validate_interaction_state("interact_request", InteractionState.Ready):
		return false
	
	if not item or not trigger_name:
		_log_warning("invalid interaction request (trigger = '%s')" % trigger_name)
		return false
	
	# TODO check it's a valid scene item or inventory item?
	
	var item_key: String = item.get_key()
	var item_id: String = item.get_id()
	
	# TODO do this much better
	var is_inventory_item: bool = item_id != item_key
	
	var routine_found: bool = _fetch_routine([item_key, trigger_name], { "self": item_id })
	
	if not routine_found:
		return false
	
	var is_telekinetic = is_inventory_item or _current_routine.is_telekinetic()
	
	if is_telekinetic:
		_run_routine()
	else:
		if not current_player:
			_log_warning("interact_request: no player and routine is not telekinetic")
			return false
		
		var target_position : Vector2 = item.get_interact_position()
		
		if not _start_walking(current_player, target_position, WalkingReason.GoingToItem):
			return false
		
	return true

func pause_request() -> bool:
	return _set_pausing(true)
	
func unpause_request() -> bool:
	return _set_pausing(false)

func _set_pausing(new_paused) -> bool:
	if _is_paused == new_paused:
		_log_warning("already %s" % ("paused" if new_paused else "unpaused"))
		return false
	
	_is_paused = new_paused
	_set_tree_paused(new_paused)
	
	return true

func _set_tree_paused(paused: bool):
	# TODO manage tree from here??
	get_tree().paused = paused
	#get_tree().set_deferred("paused", paused)

# client queries

func is_paused() -> bool:
	return _is_paused

func is_ready() -> bool:
	return _interaction_state == InteractionState.Ready

func get_current_headers() -> Array:
	if is_ready():
		if _current_routine_headers:
			_log_warning("there shouldn't be a routine")
		else:
			_log_warning("there's no current routine")
		
		return []
	
	return _current_routine_headers

func get_current_stack() -> Array:
	if is_ready():
		if _current_pointers:
			_log_warning("there shouldn't be a stack")
		else:
			_log_warning("there's no current routine")
		
		return []
	
	return _current_pointers

func get_current_room_name() -> String:
	return _current_room_name

func get_player_position() -> Vector2:
	if current_player:
		return current_player.position
	else:
		_log_warning("there's no player")
		return Vector2()

func get_global_variables() -> Array:
	var ret = []
	
	var variable_pack = symbols._get_pack("global_variable")
	
	var variable_list: Array = variable_pack.list
	
	for global_variable in variable_list:
		var variable_name: String = global_variable.symbol_name
		var variable_value = global_variable.target
		
		ret.append({
			name = variable_name,
			value = variable_value
		})
	
	return ret

func get_scene_items() -> Array:
	var ret = []
	
	var scene_items_pack = symbols._get_pack("scene_item")
	
	var scene_items_list: Array = scene_items_pack.list
	
	for scene_item in scene_items_list:
		var item_key: String = scene_item.symbol_name
		var is_disabled: bool = scene_item.disabled
		var animation_state: String = scene_item.animation
		
		ret.append({
			key = item_key,
			disabled = is_disabled,
			state = animation_state
		})
		
	return ret

func get_default_color():
	return _game_script.default_color

# load game

func _read_saved_game(saved_game: Resource) -> Dictionary:
	# TODO check game, version, etc...
	
	for global_variable in saved_game.global_variables:
		var var_name = global_variable.name
		var var_value = global_variable.value
		
		if symbols.has_symbol(var_name):
			return { valid = false, message = "duplicated global variable symbol '%s'" % var_name }
		
		symbols.add_symbol(var_name, "global_variable", var_value)
	
	for scene_item in saved_game.scene_items:
		var key = scene_item.key
		
		if symbols.has_symbol(key):
			return { valid = false, message = "duplicated scene item symbol '%s'" % key }
		
		var new_symbol = symbols.add_symbol(key, "scene_item", null)
		new_symbol.loaded = false
		new_symbol.disabled = scene_item.disabled
		new_symbol.animation = scene_item.state
	
	_current_room_name = saved_game.current_room
	_saved_player_position = saved_game.player_position
	# TODO player orientation aswell
	
	if saved_game.is_ready:
		_interaction_state = InteractionState.Ready
	else:
		_interaction_state = InteractionState.Running
		
		var routine_headers = saved_game.routine_headers
		
		# TODO recreate context
		var routine_found: bool = _fetch_routine(routine_headers, {})
		
		if not routine_found:
			return { valid = false, message = "couldn't find saved routine '%s'" % str(routine_headers) }
		
		# override pointers
		_current_pointers = saved_game.routine_stack
		
		# TODO fix this
		_skip_enabled = true
		
		# TODO what if saved while autowalking?
		# (must call _start_walking)
	
	# TODO inventory items
	# TODO aliases?
	
	# TODO curtain state
	
	return { valid = true }

# private misc

# sends events to client
func _game_event(event_name: String, args: Array = []):
	#_log_debug("SERVER EVENT '%s'" % event_name)
	emit_signal("game_event", event_name, args)

# searchs for the routine and caches it if found
func _fetch_routine(headers: Array, context: Dictionary) -> bool:
	if not _validate_game_state("_fetch_routine", GameState.Playing):
		return false
	if not _validate_interaction_state("_fetch_routine", InteractionState.Ready):
		return false
	
	var routine: Resource = _game_script.get_routine(headers)
	
	if not routine:
		_log_warning("routine '%s' not found" % str(headers))
		return false
	
	_current_routine_headers = headers
	_current_routine = routine
	_current_pointers = [-1]
	_current_context = context
	
	return true

func _get_room_resource(room_name: String):
	var room_dictionary : Dictionary = _game_script.get_rooms()
	return room_dictionary.get(room_name, null)

# validation

func _validate_game_state(func_name: String, _expected_state) -> bool:
	var valid_state: bool = _game_state == _expected_state
	
	if not valid_state:
		_log_invalid_game_state(func_name)
	
	return valid_state

func _validate_interaction_state(func_name: String, _expected_state) -> bool:
	var valid_state = _interaction_state == _expected_state
	
	if not valid_state:
		_log_invalid_interaction_state(func_name)
	
	return valid_state

func _state_str() -> String:
	var keys: Array = GameState.keys()
	if _game_state < 0 or _game_state >= keys.size():
		return "???"
	
	return keys[_game_state]

func _interaction_state_str() -> String:
	var keys: Array = InteractionState.keys()
	if _interaction_state < 0 or _interaction_state >= keys.size():
		return "???"
	
	return keys[_interaction_state]

# Static utils

static func _task_str(task: Dictionary):
	var cmd: String = task.command
	return "[%s]" % cmd.to_upper()

# Returns angle in degrees between 0 and 360
static func _get_degrees(direction: Vector2) -> float:
	var radians_angle = direction.angle()

	var deg_angle = radians_angle * 180.0 / PI

	if deg_angle < 0:
		deg_angle += 360.0

	return deg_angle


# Local logging shortcuts

func _log_invalid_game_state(func_name: String):
	_log_error("can't call '%s' while game state is %s" % [func_name, _state_str()])
func _log_invalid_interaction_state(func_name: String):
	_log_error("can't call '%s' while interaction state is %s" % [func_name, _interaction_state_str()])

func _log_debug(message: String, level = 0):
	_server._log_debug(message, "game", level)
func _log_info(message: String, level = 0):
	_server._log_info(message, "game", level)
func _log_warning(message: String, level = 0):
	_server._log_warning(message, "game", level)
func _log_error(message: String, level = 0):
	_server._log_error(message, "game", level)

func _game_warning(message: String, level = 0):
	_server._log_warning(message, _game_script.get_short_name(), level)
func _game_error(message: String, level = 0):
	_server._log_error(message, _game_script.get_short_name(), level)
