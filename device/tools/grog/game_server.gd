class_name GameServer

# server to client signals
signal game_server_event

var options = {
	default_color = Color.gray
}

# game data
var data

# current room is added as child of this node, and actors as children of the room
var root_node : Node

# Server state

enum ServerState {
	None,
	Prepared,
	Running,
	Stopping,
	Stopped
}
var _server_state = ServerState.None

var player_resource

# Live state

var current_player: Node = null # TODO needs reference? it's in symbols
var current_room: Node = null
#var interacting_item: Node = null # TODO
var interacting_symbol: Dictionary

var symbols = SymbolTable.new(["player", "scene_item", "inventory_item", "global_variable"])
var loaded_scene_items = {}
var disabled_items = {}

## Global state
#var globals = {}
#var disabled_items = {}
#var inventory_items = {}

# Cache scripts
var fallback_script: CompiledGrogScript
var default_script: CompiledGrogScript

# Intern
var runner: Runner = null # TODO reuse instead of dereference and recreate?

enum StartMode {
	Default,
	FromRawScript,
	FromScriptResource,
	FromCompiledScript
}

var _game_start_mode
var _game_start_param

const empty_action = { }

var _input_enabled = false
var _skippable = false
var _skipped = false

func init_game(game_data: Resource, p_game_start_mode = StartMode.Default, p_game_start_param = null) -> bool:
	if _server_state != ServerState.None:
		push_error("Invalid call to init_game")
		return false
	
	data = game_data
	
	if game_data.get_all_scripts().size() > 0:
		fallback_script = Grog.compile(game_data.get_all_scripts()[0])
		if not fallback_script.is_valid:
			print("Fallback script is invalid")
			fallback_script.print_errors()
			fallback_script = CompiledGrogScript.new()
	else:
		print("No fallback script")
		fallback_script = CompiledGrogScript.new()
	
	if game_data.get_all_scripts().size() > 1:
		default_script = Grog.compile(game_data.get_all_scripts()[1])
		if not default_script.is_valid:
			print("Default script is invalid")
			default_script.print_errors()
			default_script = CompiledGrogScript.new()
	else:
		print("No default script")
		default_script = CompiledGrogScript.new()
	
	_game_start_mode = p_game_start_mode
	_game_start_param = p_game_start_param
	
	match p_game_start_mode:
		StartMode.Default:
			pass
			
		StartMode.FromRawScript:
			var compiled_script = Grog.compile_text(_game_start_param)
			
			if compiled_script.is_valid:
				_game_start_param = compiled_script
			else:
				print("Script is invalid")
				compiled_script.print_errors()
				return false
		
		StartMode.FromScriptResource:
			var compiled_script = Grog.compile(_game_start_param)
			if compiled_script.is_valid:
				_game_start_param = compiled_script
			else:
				print("Script is invalid")
				compiled_script.print_errors()
				return false
		
		StartMode.FromCompiledScript:
			if not _game_start_param.is_valid:
				return false
	
	_server_state = ServerState.Prepared
	
	if not game_data.get_all_actors():
		print("No actors")
	else:
		player_resource = game_data.get_all_actors()[0]
	
	return true

##############################

func set_player(p_player_resource):
	player_resource = p_player_resource

##############################

func update(delta):
	if runner != null:
		runner.update(delta)

##############################

#	@COMMANDS

func _run_load_room(room_name: String):
	var room = _load_room(room_name)
	
	if not room:
		print("Couldn't load room '%s'" % room_name)
	
	return empty_action

func _run_enable_input():
	if _input_enabled:
		log_command_warning(["enable_input", "input is already enabled"])
		return
	
	_input_enabled = true
	_server_event("input_enabled")
	
	return empty_action

func _run_disable_input():
	if not _input_enabled:
		log_command_warning(["disable_input", "input is not enabled"])
		return
	
	_input_enabled = false
	_server_event("input_disabled")
	
	return empty_action

func _run_wait(duration: float, opts: Dictionary):
	var skippable: bool = opts.get("skippable", true) # TODO harcoded default wait skippable
	
	_server_event("wait_started", [duration, skippable])
	
	return { coroutine = _wait_coroutine(duration, skippable) }

func _run_say(item_name: String, speech_token: Dictionary, opts: Dictionary):
	var speech: String
	if speech_token.type == GrogCompiler.TOKEN_QUOTED:
		speech = speech_token.content
	else:
		speech = tr(speech_token.content)
	
	var item = null
	
	if item_name:
		var item_symbol
		
		if item_name == "self":
			item_symbol = interacting_symbol
		else:
			item_symbol = _get_interacting_item(item_name)
			if not item_symbol.type:
				return empty_action
		item = item_symbol.target
		
	# else item will be null (it's a 'global' say)
	
	var duration: float = opts.get("duration", 2.0) # TODO harcoded default say duration
	var skippable: bool = opts.get("skippable", true) # TODO harcoded default say skippable

	_server_event("say", [item, speech, duration, skippable])
	
	return { coroutine = _wait_coroutine(duration, skippable) }

func _run_walk(item_name: String, opts: Dictionary):
	var item_symbol = _get_actor_item(item_name)
	
	if not item_symbol.type:
		return empty_action
	
	var item = item_symbol.target
	
	var to_node: Node = _get_option_as_room_node("to", opts)

	if not to_node:
		push_error("parameter 'to' needed for walk")
		return empty_action
	
	var target_position = to_node.position
	
	return _run_walk_resolved(item, target_position)

func _run_walk_resolved(actor, target_position: Vector2, global = false) -> Dictionary:
	var nav : Navigation2D = current_room.get_navigation()
	
	if not nav:
		return empty_action
	
	if global:
		target_position = target_position - nav.global_position
	
	target_position = nav.get_closest_point(target_position)
	
	var current_position = actor.position
	
	var path = nav.get_simple_path(current_position, target_position)
	
	return { coroutine = _walk_coroutine(actor, path) }
	
func _run_end():
	return { stop = true }

func _run_set(var_name: String, new_value: bool):
	var symbol = symbols.get_symbol_of_types(var_name, ["global_variable"], false)
	
	if symbol == null:
		# it's absent
		symbols.add_symbol(var_name, "global_variable", new_value)
	elif not symbol.type:
		# type mismatch
		pass
	else:
		# already present
		if new_value != symbol.target:
			# value changed
			symbol.target = new_value
	
	return empty_action

func _run_enable(item_id: String):
	var item_symbol
	if item_id == "self":
		item_symbol = interacting_symbol
		item_id = interacting_symbol.symbol_name
	else:
		item_symbol = _get_scene_item(item_id)
		if not item_symbol.type:
			return
	
	if not item_symbol.disabled:
		print("Item '%s' is already enabled")
		return empty_action
	
	disabled_items.erase(item_id)
	item_symbol.disabled = false
	
	if item_symbol.loaded:
		var item1 = loaded_scene_items[item_id]
		var item2 = item_symbol.target
		
		if item1 != item2:
			print("Inconsistent %s != %s" % [item1, item2])
			return empty_action
	
		item1.enable()
		_server_event("item_enabled", [item1])
	
	return empty_action
	
func _run_disable(item_id: String):
	var item_symbol
	if item_id == "self":
		item_symbol = interacting_symbol
		item_id = interacting_symbol.symbol_name
	else:
		item_symbol = _get_scene_item(item_id)
		if not item_symbol.type:
			return
	
	if item_symbol.disabled:
		print("Item '%s' is already disabled")
		return empty_action
	
	disabled_items[item_id] = true
	item_symbol.disabled = true
	
	if item_symbol.loaded:
		var item1 = loaded_scene_items[item_id]
		var item2 = item_symbol.target
		
		if item1 != item2:
			print("Inconsistent %s != %s" % [item1, item2])
			return empty_action
	
		item1.disable()
		_server_event("item_disabled", [item1])
	
	return empty_action

func _run_add(item_name: String):
	var item_symbol = symbols.get_symbol_of_types(item_name, ["inventory_item"], false)
	
	if item_symbol == null:
		#absent
		symbols.add_symbol(item_name, "inventory_item", true)
		_server_event("item_added", [item_name])
	elif not item_symbol.type:
		# type mismatch
		print("No inventory_item '%s'" % item_name)
	else:
		# already present
		print("Already has inventory item '%s'" % item_name)
	
	return empty_action

func _run_remove(item_name: String):
	var item_symbol = symbols.get_symbol_of_types(item_name, ["inventory_item"], false)
	
	if item_symbol == null or not item_symbol.type:
		# absent or type mismatch
		print("No inventory_item '%s'" % item_name)
	else:
		# already present
		print("Implement _run_remove!")

		#symbols.remove_symbol(item_name)
		#_server_event("item_removed", [item_name])
		
	return empty_action
	
#func new_command():
#	return empty_action

#func new_command(subject: String):
#	return empty_action

#func new_command(subject: String, opts: Dictionary):
#	return empty_action

##############################

#	@CLIENT REQUESTS

func start_game_request(p_root_node: Node) -> bool:
	if _server_state != ServerState.Prepared:
		push_error("Invalid start_game request")
		return false
	
	root_node = p_root_node
	
	if player_resource:
		if player_resource.actor_scene:
			current_player = player_resource.actor_scene.instance()
			symbols.add_symbol("you", "player", current_player)
		else:
			print("No actor scene in actor resource")
	
	_server_event("game_started", [current_player])
	
	match _game_start_mode:
		StartMode.Default:
			_run_compiled(default_script, "start")
		
		_:
			_run_compiled(_game_start_param, "start")
	
	_server_state = ServerState.Running
	return true
	
func skip_request():
	if _skippable and not _skipped:
		_skipped = true

func go_to_request(target_position: Vector2):
	
	if _server_state != ServerState.Running:
		return
	
	if not _input_enabled or not current_player:
		return
	
	if is_busy():
		# TODO cancel current actions
		#print("I'm busy'")
		return
	
	_run([{
		type = "command",
		command = "walk_resolved",
		params = [
			current_player,
			target_position,
			true
		]
	}])
	
func interact_request(item: Node2D, trigger_name: String):
	if _server_state != ServerState.Running:
		return
	
	if not _input_enabled or not current_player:
		return
	
	var symbol = _get_scene_item(item.global_id)
	
	assert(symbol.type == "scene_item")
	assert(symbol.symbol_name == item.global_id)
	assert(symbol.target == item)
	
	assert(current_room.is_a_parent_of(item))
	assert(symbol.loaded)
	
	assert(symbol.disabled == disabled_items.has(item.global_id))
	
	if symbol.disabled:
		print("Item '%s' is disabled" % item.global_id)
		return
	
#	if not current_room.is_a_parent_of(item):
#		print("No item in room")
#		return
#
	if is_busy():
		# TODO cancel current actions
		#print("I'm busy'")
		return
	
	var _sequence: Dictionary = item.get_sequence(trigger_name)
	
	if not _sequence.has("statements"):
		# get fallback
		_sequence = fallback_script.get_sequence(trigger_name)
	
	# TODO context and avoid duplication
	
	#assert(not symbols.has_symbol("self"))
	#symbols.add_symbol("self", "scene_item",)
	
	interacting_symbol = symbol
	
	var instructions = _sequence.statements.duplicate(true)
	
	if not _sequence.telekinetic:
		var target_position = item.get_interact_position()
		instructions.push_front({
			type = "command",
			command = "walk_resolved",
			params = [
				current_player,
				target_position
			]
		})
	
	_run(instructions)
	
	# should clean interacting_symbol

func stop_request():
	if _server_state != ServerState.Running:
		print("Unexpected stop")
		return
	
	if runner:
		_server_state = ServerState.Stopping
		runner.stop_asap()
	else:
		_stop()

func _stop():
	_server_state = ServerState.Stopped
	_free_all()
	_server_event("game_ended")

##############################

#	@PRIVATE

func _server_event(event_name: String, args: Array = []):
	emit_signal("game_server_event", event_name, args)

func _load_room(room_name: String) -> Node:
	var room_resource = _get_room_resource(room_name)
	if not room_resource:
		print("No room '%s'" % room_name)
		return null
	
	if not room_resource.room_scene:
		print("No room_scene in room '%s'" % room_name)
		return null
	
	var room = room_resource.room_scene.instance()
	
	if not room:
		push_error("Couldn't load room '%s'"  % room_name)
		return null
	
	# detaches player from previous room
	if current_room and current_player:
		current_room.remove_child(current_player)
	
	if current_room:
#		for item_key in loaded_scene_items:
#			print("TODO: A.Disable item '%s'!!!" % item_key)
#
#		for item in current_room.get_items():
#			print("TODO: B.Disable item '%s'!!!" % item.global_id)
		
		for item_key in loaded_scene_items:
			var item_symbol = symbols.get_symbol(item_key)
			
			assert(item_symbol.type == "scene_item")
			assert(item_symbol.loaded)
			
			if not item_symbol.disabled:
				# then is loaded, so tell the client to disable it
				_server_event("item_disabled", [item_symbol.target])
			
			item_symbol.loaded = false
		
		loaded_scene_items = {}
		
		root_node.remove_child(current_room)
		current_room.queue_free()
		current_room = null
	
	current_room = room
	
	if current_player:
		room.add_child(current_player)
		current_player.teleport(room.get_default_player_position())
	else:
		print("Playing with no player")
	
	# care: items are not _ready yet
	
	for item in room.get_items():
		var item_id = item.global_id
		var item_symbol = symbols.get_symbol_of_types(item_id, ["scene_item"], false)
		
		if item_symbol == null:
			# absent
			item_symbol = symbols.add_symbol(item_id, "scene_item", item)
			item_symbol.disabled = false
			item_symbol.loaded = false
		elif not item_symbol.type:
			# type mismatch
			print("Symbol '%s' was registered as %s" % [item_id, symbols.get_symbol_type(item_id)])
			continue
		else:
			# already present
			# reload item, it was destroyed when destroying a previous room
			
			item_symbol.target = item
		
		assert(not item_symbol.loaded)
		item_symbol.loaded = true
		assert(not loaded_scene_items.has(item_id))
		loaded_scene_items[item_id] = item
		
		if item_symbol.disabled:
			item.disable()
		else:
			_server_event("item_enabled", [item])
	
	root_node.add_child(room) # _ready is called here for room and its items
	
	_server_event("room_loaded", [room]) # TODO parameter is not necessary

	return room

func _wait_coroutine(delay_seconds: float, skippable: bool):
	var elapsed = 0.0
	
	_skippable = skippable
	_skipped = false
	
	while elapsed < delay_seconds:
		if _skipped:
			break
		elapsed += yield()
	
	_skippable = false
	
	_server_event("wait_ended")

func _walk_coroutine(item, path: PoolVector2Array):
	while path.size() >= 2:
		var time = 0.0
	
		var origin: Vector2 = path[0]
		var destiny: Vector2 = path[1]
		
		var displacement = destiny - origin
		var distance2 = displacement.length_squared()
		var direction = displacement.normalized()
		
		item.emit_signal("start_walking", direction)
		
		var finish_step = false
		
		while not finish_step:
			time += yield()
			
			var step_distance = item.walk_speed * time
			
			var target_point = origin + step_distance * direction
			if pow(step_distance, 2) >= distance2:
				item.teleport(destiny)
				finish_step = true
			else:
				item.teleport(target_point)
			
		path.remove(0)
	
	item.emit_signal("stop_walking")

func _free_all():
	if current_player:
		if current_room:
			current_room.remove_child(current_player)
		current_player.queue_free()
		current_player = null
	
	if current_room:
		root_node.remove_child(current_room)
		current_room.queue_free()
		current_room = null
	
	# TODO also free another actors and items
	
##############################

#	@RUNNING

func is_busy():
	return runner != null

func _runner_over(status):
	runner = null
	if _server_state == ServerState.Stopping:
		if status != Runner.RunnerStatus.Canceled:
			print("Expecting runner canceled")
		
		_stop()
	else:
		if status == Runner.RunnerStatus.Canceled:
			print("Not expected cancel")
		
	#print("Runner over with status %s" % Runner.RunnerStatus.keys()[status])

# TODO change name of this functions starting with '_run' like commands

func _run(instructions: Array):
	assert(runner == null)
	
	runner = Runner.new()
	
	var r = runner.run(instructions, self)
	
	if not r:
		runner = null
	
	# else it's running and i'm busy until this runner is over
	
func _run_script_named(script_name: String, sequence_name: String):
	var script_resource = _get_script_resource(script_name)
	
	if not script_resource:
		print("No script '%s'" % script_name)
		return
	
	_run_script(script_resource, sequence_name)

func _run_script(script_resource: Resource, sequence_name: String):
	var compiled_script = Grog.compile(script_resource)
	if not compiled_script.is_valid:
		print("Script is invalid")

		compiled_script.print_errors()
		return

	_run_compiled(compiled_script, sequence_name)

func _run_compiled(compiled_script: CompiledGrogScript, sequence_name: String):
	if compiled_script.has_sequence(sequence_name):
		var sequence = compiled_script.get_sequence(sequence_name)
		
		if is_busy():
			#print("I'm busy")
			return
		
		# TODO context and avoid duplication
		var instructions = sequence.statements.duplicate(true)
		_run(instructions)
		
	else:
		print("Sequence '%s' not found" % sequence_name)

##############################

#	@FIND ITEMS AND RESOURCES

func _get_room_resource(room_name):
	return _get_resource_in(data.get_all_rooms(), room_name)

func _get_actor_resource(actor_name):
	return _get_resource_in(data.get_all_actors(), actor_name)

func _get_script_resource(script_name):
	return _get_resource_in(data.get_all_scripts(), script_name)

func _get_resource_in(list, elem_name):
	for i in range(list.size()):
		var elem = list[i]
		
		if elem.get_name() == elem_name:
			return elem
	return null

##############################

#	@MISC

func _get_option_as_room_node(option_name: String, opts: Dictionary) -> Node:
	if not opts.has(option_name):
		return null
	
	var node_name: String = opts[option_name]
	
	if not current_room.has_node(node_name):
		print("Node '%s' not found" % node_name)
		return null
		
	return current_room.get_node(node_name)

##############################

#	@LOGGING

enum LogLevel {
	Ok,
	Warning,
	Error
}

func log_command_ok(args: Array):
	log_command(LogLevel.Ok, args)
	
func log_command_warning(args: Array):
	log_command(LogLevel.Warning, args)

func log_command_error(args: Array):
	log_command(LogLevel.Error, args)
	
func log_command(level, args: Array):
	print("%s:\t%s" % [LogLevel.keys()[level], args])

##############################

#	@GLOBAL STATE ACCESS

func get_state():
	return _server_state

# finds an actor, inventory item or a scene item that is loaded and enabled
func _get_interacting_item(item_id: String) -> Dictionary:
	var symbol = symbols.get_symbol_of_types(item_id, ["player", "scene_item"], true)
	
	if not symbol.type:
		print("No item '%s'" % item_id)
		return symbol
	
	if symbol.type == "scene_item":
		if not symbol.loaded:
			print("Item '%s' is not in this room (can't interact)" % item_id)
			return SymbolTable.empty_symbol
		
		if symbol.disabled:
			print("Item '%s' is disabled (can't interact)" % item_id)
			return SymbolTable.empty_symbol
	
	assert(symbol.target)
	
	return symbol
	
# is required
func _get_scene_item(item_id: String) -> Dictionary:
	var symbol = symbols.get_symbol_of_types(item_id, ["scene_item"], true)
	if not symbol.type:
		print("No scene item '%s'" % item_id)
		return symbol
	
	var in_scene1 = loaded_scene_items.has(item_id)
	var in_scene2 = symbol.loaded
	
	if in_scene1 != in_scene2:
		print("Inconsistent %s != %s" % [in_scene1, in_scene2])
		return SymbolTable.empty_symbol
	
	var disabled1 = disabled_items.has(item_id)
	var disabled2 = symbol.disabled
	
	if disabled1 != disabled2:
		print("Inconsistent %s != %s" % [disabled1, disabled2])
		return SymbolTable.empty_symbol
	
	return symbol

# is required
func _get_actor_item(item_id: String) -> Dictionary:
	var symbol = symbols.get_symbol_of_types(item_id, ["player"], true)
	
	if not symbol.type:
		print("No actor '%s'" % item_id)
		return symbol
	
	assert(current_player != null)
	assert(current_player == symbol.target)
	
	return symbol
	
func get_global(var_name: String):
	var symbol = symbols.get_symbol_of_types(var_name, ["global_variable"], false)
	
	if symbol == null:
		# absent
		return false
	elif not symbol.type:
		# type mismatch
		print("No global_variable '%s'" % [var_name])
		return false
	else:
		return symbol.target
	
