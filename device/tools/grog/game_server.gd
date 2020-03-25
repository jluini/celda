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

# Game state
var globals = {}
var disabled_items = {}
var inventory_items = {}

var current_room: Node = null
var current_player: Node = null

var fallback_script: CompiledGrogScript
var default_script: CompiledGrogScript

var runner: Runner = null

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
		fallback_script = grog.compile(game_data.get_all_scripts()[0])
		if not fallback_script.is_valid:
			print("Fallback script is invalid")
			fallback_script.print_errors()
			fallback_script = CompiledGrogScript.new()
	else:
		print("No fallback script")
		fallback_script = CompiledGrogScript.new()
	
	if game_data.get_all_scripts().size() > 1:
		default_script = grog.compile(game_data.get_all_scripts()[1])
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
			var compiled_script = grog.compile_text(_game_start_param)
			
			if compiled_script.is_valid:
				_game_start_param = compiled_script
			else:
				print("Script is invalid")
				compiled_script.print_errors()
				return false
		
		StartMode.FromScriptResource:
			var compiled_script = grog.compile(_game_start_param)
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
	
	return true

##############################

#	@COMMANDS

func _run_load_room(room_name: String, _opts = {}):
	var room = _load_room(room_name)
	
	if room:
		# TODO check this (clearing player when loading new room)
		current_player = null
	else:
		print("Couldn't load room '%s'" % room_name)
	
	return empty_action

func _run_load_actor(actor_name: String, opts = {}):
	if not current_room:
		print("There's no room!")
		return empty_action
	
	var starting_position
	
	var at_node: Node = _get_option_as_room_node("at", opts)
	
	if at_node:
		starting_position = at_node.position
	else:
		starting_position = current_room.get_default_player_position()

	var actor = _load_actor(actor_name, starting_position)
	
	if not actor:
		print("Couldn't load actor '%s'" % actor_name)
		return
	
	# TODO
	if not current_player:
		current_player = actor
	
	return empty_action

func _run_enable_input(_opts = {}):
	if _input_enabled:
		log_command_warning(["enable_input", "input is already enabled"])
		return
	
	_input_enabled = true
	_server_event("input_enabled")
	
	return empty_action

func _run_disable_input(_opts = {}):
	if not _input_enabled:
		log_command_warning(["disable_input", "input is not enabled"])
		return
	
	_input_enabled = false
	_server_event("input_disabled")
	
	return empty_action

func _run_wait(duration: float, opts = {}):
	var skippable: bool = opts.get("skippable", true) # TODO harcoded default wait skippable
	
	_server_event("wait_started", [duration, skippable])
	
	return { coroutine = _wait_coroutine(duration, skippable) }

func _run_say(item_name: String, speech_token: Dictionary, opts = {}):
	var speech: String
	if speech_token.type == GrogCompiler.TOKEN_QUOTED:
		speech = speech_token.content
	else:
		speech = tr(speech_token.content)
	
	var item = null
	if item_name:
		item = _get_item_named(item_name)
		if not item:
			return empty_action
	
	# else is a 'global' say
	
	var duration: float = opts.get("duration", 2.0) # TODO harcoded default say duration
	var skippable: bool = opts.get("skippable", true) # TODO harcoded default say skippable

	_server_event("say", [item, speech, duration, skippable])
	
	return { coroutine = _wait_coroutine(duration, skippable) }

func _run_walk(item_name: String, opts: Dictionary):
	if not item_name:
		print("Walk action needs a subject") # TODO check in compiler?
		return empty_action
	
	var item = _get_item_named(item_name)
	if not item:
		return empty_action
	
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
	
func _run_end(_opts = {}):
	return { stop = true }

func _run_set(var_name: String, value: bool, _opts = {}):
	_set_global(var_name, value)
	
	return empty_action

func _run_enable(subject: String, _opts = {}):
	_enable_item(subject)
	return empty_action
	
func _run_disable(subject: String, _opts = {}):
	_disable_item(subject)
	return empty_action

#func new_command(_opts = {}):
#	return empty_action

#func new_command(subject: String, _opts = {}):
#	return empty_action

##############################

#	@CLIENT REQUESTS

func start_game_request(p_root_node: Node) -> bool:
	if _server_state != ServerState.Prepared:
		push_error("Invalid start_game request")
		return false
	
	root_node = p_root_node
	
	_server_event("game_started")
	
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
		
	if not current_room.is_a_parent_of(item):
		print("No item in room")
		return
	
	if is_busy():
		# TODO cancel current actions
		#print("I'm busy'")
		return
	
	var context = {
		"self": item.global_id,
		"you": current_player.global_id
	}
	
	var _sequence: Sequence = item.get_sequence(trigger_name)
	
	if _sequence == null:
		# get fallback
		_sequence = fallback_script.get_sequence(trigger_name)
	
	var instructions = _sequence.in_context(context)
	
	if not _sequence.is_telekinetic():
		var target_position = item.get_interact_position()
		instructions.push_front({
			command = "walk_resolved",
			params = [
				current_player,
				target_position
			]
		})
	
	_run(instructions)

func stop_request():
	if _server_state != ServerState.Running:
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

#	@EVENT QUEUE EVENTS

func _event_queue_set_ready():
	pass # _server_event("set_ready")

func _event_queue_stopped():
	# TODO
	_free_all()
	_server_event("game_ended")

##############################

#	@PRIVATE

func _server_event(event_name: String, args: Array = []):
	emit_signal("game_server_event", event_name, args)

func _load_room(room_name: String) -> Node:
	var room_resource = _get_room(room_name)
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
	
	_free_all()
	
	current_room = room
	
	# care: items are not _ready yet
	
	for item in current_room.get_items():
		var item_id = item.global_id
		#print("Loading item '%s'" % item_id)
		
		if _item_is_disabled(item_id):
			item.disable()
	
	root_node.add_child(room) # _ready is called here for room and its items
	
	_server_event("room_loaded", [room]) # TODO parameter is not necessary

	return room

func _load_actor(actor_name: String, starting_position: Vector2) -> Node:
	var actor_resource = _get_actor(actor_name)
	if not actor_resource:
		print("No actor '%s'" % actor_name)
		return null
	
	if not actor_resource.actor_scene:
		print("No actor_scene in actor '%s'" % actor_name)
		return null
	
	var actor = actor_resource.actor_scene.instance()
	
	if not actor:
		push_error("Couldn't load actor '%s'"  % actor_name)
		return null
	
	current_room.add_child(actor)
	
	actor.teleport(starting_position)
	
	_server_event("actor_loaded", [actor])
	
	return actor

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
	
	#print("Runner over with status %s" % Runner.RunnerStatus.keys()[status])

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
	var compiled_script = grog.compile(script_resource)
	if not compiled_script.is_valid:
		print("Script is invalid")

		compiled_script.print_errors()
		return

	_run_compiled(compiled_script, sequence_name)

func _run_compiled(compiled_script: CompiledGrogScript, sequence_name: String):
	if compiled_script.has_sequence(sequence_name):
		var sequence: Sequence = compiled_script.get_sequence(sequence_name)
		
		if is_busy():
			#print("I'm busy")
			return
		
		_run(sequence.in_context({}))
		
	else:
		print("Sequence '%s' not found" % sequence_name)

##############################

#	@FIND ITEMS AND RESOURCES

func _get_item_named(item_name: String) -> Node:
	var item = _find_item_named(item_name)
	if not item:
		print("Unknown item '%s'" % item_name)
		return null
	
	return item
	
func _find_item_named(item_name: String) -> Node:
	# TODO make it efficient
	var items = grog.tree.get_nodes_in_group("item")
	
	for i in items:
		if i.global_id == item_name:
			return i
	
	return null

func _get_room(room_name):
	return _get_resource_in(data.get_all_rooms(), room_name)

func _get_actor(actor_name):
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

func _set_global(var_name, value):
	globals[var_name] = value

func _item_is_disabled(item_id):
	return disabled_items.has(item_id)

func _enable_item(item_id):
	if _item_is_disabled(item_id):
		disabled_items.erase(item_id)
		
		var item = _find_item_named(item_id)
		
		if item:
			# item is in scene
			item.enable()
	else:
		print("'%s' is already enabled" % item_id)

func _disable_item(item_id):
	if not _item_is_disabled(item_id):
		disabled_items[item_id] = true
		
		var item = _find_item_named(item_id)
		
		if item:
			# item is in scene
			item.disable()
			
	else:
		print("'%s' is already disabled" % item_id)
	
