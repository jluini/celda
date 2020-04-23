class_name GameServer

# server to client signals
signal game_server_event

var options = {
	default_color = Color.gray
}

#compiler
var compiler

# game data
var data

# current room is added as child of this node, and actors as children of the room
var root_node : Node

# Server state

enum ServerState {
	None,
	Prepared,
	Initializing,
	RunningSequence, # _is_skippable is changed according to instructions
	Serving,         # it may have a _goal and be _is_cancelable
	Ready,
	Stopping,
	Stopped
}
var _server_state = ServerState.None

var _is_skippable = false
var _skipped = false
var _is_cancelable = false
var _canceled = false

var _goal = null
var _walking_subject: Node
var _walking_path: PoolVector2Array
var _path_changed = false

# Live state
var symbols = SymbolTable.new([
	"player",
	"global_variable",
	"scene_item",
	"inventory_item",
	"inventory_item_instance",
])

var loaded_scene_items = {}

var inventory_items_scene: Node

var current_player: Node = null # TODO needs reference? it's in symbols
var current_room: Node = null

#var interacting_symbol = null
#var interacting_tool_symbol = null

#var current_tool_symbol = null
#var current_tool_verb = ""

# Player to use (currently constant)
var player_resource

# Cache scripts
#var default_script

# Intern
var runner: Runner = null # TODO reuse instead of dereference and recreate?

var interact_distance_threshold = 10

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

var _compiled_scripts = []


func init_game(p_compiler, game_data: Resource, p_game_start_mode, p_game_start_param) -> bool:
	if _server_state != ServerState.None:
		push_error("Invalid call to init_game")
		return false
	
	compiler = p_compiler
	data = game_data
	
	var scripts = game_data.get_all_scripts()
	var number_of_scripts = scripts.size()
	
	if number_of_scripts == 0:
		print("No scripts")
		_compiled_scripts.append(CompiledGrogScript.new())
	
	for i in range(number_of_scripts):
		var compiled = compiler.compile_text(scripts[i].get_code())
		if not compiled.is_valid:
			print("Starting script %s is invalid" % i)
			compiled.print_errors()
			compiled = CompiledGrogScript.new() # replaces it by an empty script
		
		_compiled_scripts.append(compiled)
	
#	if number_of_scripts > 0:
#		default_script = compiler.compile_text(game_data.get_all_scripts()[0].get_code())
#		if not default_script.is_valid:
#			print("Default script is invalid")
#			default_script.print_errors()
#			default_script = CompiledGrogScript.new()
	
	_game_start_mode = p_game_start_mode
	_game_start_param = p_game_start_param
		
	match _game_start_mode:
		StartMode.Default:
			if typeof(_game_start_param) != TYPE_INT or _game_start_param < 0:
				print("Expected non-negative int as param")
				return false
			elif _game_start_param >= number_of_scripts:
				print("Starting script %s out of bounds" % _game_start_param)
				return false
			
			#_game_start_param = game_data.get_all_scripts()[_game_start_param]
		
#		StartMode.FromRoom:
#			var compiled_script = CompiledGrogScript.new()
#			var start_sequence = build_start_sequence(_game_start_param)
#
#			compiled_script.add_sequence("start", start_sequence)
#			_game_start_param = compiled_script
		_:
			print("Grog error: start mode %s not implemented" % StartMode.keys()[_game_start_mode])
			return false
	
	_server_state = ServerState.Prepared
	
	if not game_data.get_all_actors():
		print("No actors")
	else:
		player_resource = game_data.get_all_actors()[0]
	
	if not game_data.inventory_items_scene:
		print("No inventory_items_scene in game data")
		return false
	
	inventory_items_scene = game_data.inventory_items_scene.instance()
	
	for ii in inventory_items_scene.get_children():
		if not ii.has_node("item"):
			print("Inventory item %s has no child named 'item'" % ii.get_name())
			continue
		
		var item = ii.get_node("item")
		
		var id = item.get_id()
		item.init_item(compiler)
		
		if symbols.has_symbol(id):
			print("Duplicated inventory item id '%s'" % id)
			continue
		
		var new_symbol = symbols.add_symbol(id, "inventory_item", item)
		new_symbol.amount = 0
		new_symbol.last_instance_number = 0
		#new_symbol.instances = []
		
	return true

##############################

func build_start_sequence(room_resource):
	var ret = []

	ret.append({ type="command", command="load_room", params=[room_resource.get_name()] })
	ret.append({ type="command", command = "curtain_up", params = [] })
	ret.append({ type="command", command = "enable_input", params = [] })

	return { statements=ret, telekinetic=false }

##############################

func set_player(p_player_resource):
	player_resource = p_player_resource

##############################

func update(delta):
	if runner != null:
		runner.update(delta)

##############################

#	@COMMANDS

func _command_load_room(room_name: String) -> Dictionary:
	if _server_state != ServerState.RunningSequence:
		if _server_state == ServerState.Initializing:
			print("Can't load rooms in initialization phase")
		
		return empty_action
		
	#var room = _load_room(room_name)
	
	var room_resource = _get_room_resource(room_name)
	if not room_resource:
		print("No room '%s'" % room_name)
		return empty_action
	
	if not room_resource.get_target():
		print("No target scene in room resource '%s'" % room_name)
		return empty_action
	
	var room = room_resource.get_target().instance()
	
	if not room:
		push_error("Couldn't load room '%s'"  % room_name)
		return empty_action
	
	var theres_and_old_room = current_room != null
	
	if theres_and_old_room:
		_server_event("curtain_down")
		
		var duration = 1.0
		_is_skippable = false
		
		_skipped = false
		
		var load_coroutine = _load_room_coroutine(room)
		
		var coroutine_state = _wait_coroutine(duration, load_coroutine)
		
		var ret = { coroutine = coroutine_state }
		
		return ret
	
	else:
		return { coroutine = _load_room_coroutine(room) }

func _load_room_coroutine(room):
	yield()
	
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
		#current_player.scale = Vector2(2, 2)
		#current_player.set_angle(90)
	else:
		print("Playing with no player")
	
	# care: items are not _ready yet
	
	for item in room.get_items():
		var item_key = item.get_key()
		
		if not item_key:
			print("Item with empty key in room '%s'" % room.get_name())
			continue
		elif item_key in ["self", "tool", "if"]: # TODO better check
			print("An item can't have '%s' as id" % item_key)
			continue
		elif loaded_scene_items.has(item_key):
			print("Duplicated scene item '%s'" % item_key)
			continue
		
		var item_symbol = _get_or_build_scene_item(item_key, "load")
		
		if not item_symbol:
			# type mismatch
			continue
		
		item_symbol.target = item
		item_symbol.target.init_item(compiler)
		assert(not item_symbol.loaded)
		item_symbol.loaded = true
		loaded_scene_items[item_key] = item
		
		if item_symbol.disabled:
			item.disable()
		else:
			if item.has_node("animation"):
				item.get_node("animation").play(item_symbol.animation)
			_server_event("item_enabled", [item])
	
	root_node.add_child(room) # _ready is called here for room and its items
	
	_server_event("room_loaded", [room]) # TODO parameter is not necessary
	
func _command_enable_input() -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	if _input_enabled:
		print("input is already enabled")
		return empty_action
	
	_input_enabled = true
	_server_event("input_enabled")
	
	return empty_action

func _command_disable_input() -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	if not _input_enabled:
		print("input is already disabled")
		return empty_action
	
	_input_enabled = false
	_server_event("input_disabled")
	
	return empty_action

func _command_wait(duration: float, opts: Dictionary) -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	_is_skippable = opts.get("skippable", true) # TODO harcoded default wait skippable
	
	_server_event("wait_started", [duration, _is_skippable])
	
	if _skipped:
		print("Old skipped 1")
		_skipped = false
	
	return { coroutine = _wait_coroutine(duration) }

func _command_say(item_id: String, speech_token: Dictionary, opts: Dictionary) -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	var speech = speech_token.expression.evaluate(self)
	
	if typeof(speech) != TYPE_STRING:
		print("Saying not string: %s" % Grog._typestr(speech))
		speech = str(speech)
	
	if speech_token.type != Grog.TokenType.Quote:
		speech = tr(speech)
	
	var item = null
	
	if item_id:
		var item_symbol = symbols.get_symbol_of_types(item_id, ["player", "scene_item"], true) 
		item_id = item_symbol.symbol_name
		
		if not item_symbol.type:
			# absent
			return empty_action
		elif item_symbol.type == "scene_item":
			if not item_symbol.loaded:
				print("Item '%s' can't speak: isn't loaded" % item_id)
				return empty_action
			elif item_symbol.disabled:
				print("Item '%s' can't speak: is disabled" % item_id)
				return empty_action
		
		item = item_symbol.target
		
	# else item will be null (it's a 'global' say)
	
	var duration: float = opts.get("duration", 2.0) # TODO harcoded default say duration
	_is_skippable = opts.get("skippable", true) # TODO harcoded default say skippable

	_server_event("say", [item, speech, duration, _is_skippable])
	
	if _skipped:
		print("Old skipped 2")
		_skipped = false
	
	return { coroutine = _wait_coroutine(duration) }

func _command_walk(item_id: String, to_node_named: String) -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	var item_symbol = symbols.get_symbol_of_types(item_id, ["player"], true)
	
	if not item_symbol.type:
		print("No actor '%s'" % item_id)
		return empty_action
	
	var item = item_symbol.target
	
	var to_node_symbol = symbols.get_symbol_of_types(to_node_named, ["scene_item"], false)
	
	var to_node
	
	if to_node_symbol == null:
		# absent
		if not current_room.has_node(to_node_named):
			print("Node '%s' not found" % to_node_named)
			return empty_action
		else:
			to_node = current_room.get_node(to_node_named)
	
	elif not to_node_symbol.type:
		# type mismatch
		print("Can't walk to an object of type '%s'" % symbols.get_symbol_type(to_node_named))
		return empty_action
	else:
		if not to_node_symbol.loaded:
			print("walk: item '%s' is not in current room" % to_node_named)
			return empty_action
		elif to_node_symbol.disabled:
			print("walk: item '%s' is disabled" % to_node_named)
			return empty_action
		else:
			to_node = to_node_symbol.target
		
	var target_position = to_node.position
	
	var path = build_path(item.position, target_position, false)
	
	if not path:
		print("No path")
		return empty_action
	
	_path_changed = true
	_walking_path = path
	_walking_subject = item
	_goal = null
	
	return _command_intern_walk()
	
func _command_end() -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	_server_state = ServerState.Stopping
	return { stop = true }

func _command_set(var_name: String, new_value_expression) -> Dictionary:
	var new_value = new_value_expression.evaluate(self)
	
	#print("Setting global '%s' to '%s' (type %s, class %s)" % [var_name, new_value, Grog._typestr(new_value), new_value.get_class() if typeof(new_value) == TYPE_OBJECT else "-"])
	
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
	
	_server_event("variable_set", [var_name, new_value])
	
	return empty_action

func _command_enable(item_key: String) -> Dictionary:
	var item_symbol = _get_or_build_scene_item(item_key, "enable")
	
	if not item_symbol:
		return empty_action
	
	item_key = item_symbol.symbol_name
	
	if not item_symbol.disabled:
		print("Item '%s' is already enabled" % item_key)
		return empty_action
	
	item_symbol.disabled = false

	if item_symbol.loaded:
		var item = item_symbol.target
		assert(item == loaded_scene_items[item_key])

		item.enable()
		_server_event("item_enabled", [item])

	return empty_action
	
func _command_disable(item_key: String) -> Dictionary:
	var item_symbol = _get_or_build_scene_item(item_key, "disable")
	
	if not item_symbol:
		return empty_action
	
	item_key = item_symbol.symbol_name
	
	if item_symbol.disabled:
		print("Item '%s' is already disabled" % item_key)
		return empty_action
	
	item_symbol.disabled = true

	if item_symbol.loaded:
		var item = item_symbol.target
		assert(item == loaded_scene_items[item_key])

		item.disable()
		_server_event("item_disabled", [item])

	return empty_action
	
func _command_add(inv_key: String) -> Dictionary:
	var item_symbol = symbols.get_symbol_of_types(inv_key, ["inventory_item"], true)
	
	if not item_symbol.type:
		print("No inventory_item '%s'" % inv_key)
		return empty_action
	
	item_symbol.amount += 1
	
	var new_instance_number: int = item_symbol.last_instance_number + 1
	item_symbol.last_instance_number = new_instance_number
	var new_symbol_id = inv_key + "." + str(new_instance_number)

	var target_node: Node = item_symbol.target
	var new_instance = target_node.duplicate(Node.DUPLICATE_SCRIPTS)
	
	new_instance._compiled_script = target_node._compiled_script
	new_instance.instance_number = new_instance_number
	
	assert(new_symbol_id == new_instance.get_id())
	
	# TODO check no symbol can collide with this...
	symbols.add_symbol(new_symbol_id, "inventory_item_instance", new_instance)
	
	_server_event("item_added", [new_instance])
	
	return empty_action

func _command_remove(item_id: String) -> Dictionary:
	var instance_symbol = symbols.get_symbol_of_types(item_id, ["inventory_item_instance"], true)
	
	if not instance_symbol.type:
		print("No inventory_item_instance '%s'" % item_id)
		return empty_action
	
	item_id = instance_symbol.symbol_name
	
	var last_dot_index = item_id.find_last(".")
	if last_dot_index <= 0 or item_id.length() < last_dot_index + 2:
		print("Invalid inventory_item_instance id '%s'" % item_id)
		return empty_action
	
	var item_id_without_index = item_id.substr(0, last_dot_index)
	var instance_number = int(item_id.substr(last_dot_index + 1))
	
	assert(instance_symbol.target.get_id() == item_id)
	assert(instance_symbol.target.get_key() == item_id_without_index)
	assert(instance_symbol.target.instance_number == instance_number)
	var item_class_symbol = symbols.get_symbol_of_types(item_id_without_index, ["inventory_item"], true)
	assert(item_class_symbol.type == "inventory_item" and item_class_symbol.target.get_id() == item_id_without_index)
	
	item_class_symbol.amount -= 1
	
	# TODO 
	
	_server_event("item_removed", [instance_symbol.target])
	
	instance_symbol.target.queue_free()
	
	var _r = symbols.remove_symbol(item_id)
	
	if symbols.has_alias("self") and symbols.get_alias("self") == item_id:
		symbols.remove_alias("self")
	if symbols.has_alias("tool") and symbols.get_alias("tool") == item_id:
		symbols.remove_alias("tool")
	
	return empty_action

func _command_play(item_id: String, animation_name_token: Dictionary) -> Dictionary:
	var animation_name = animation_name_token.expression.evaluate(self)
	
	var item_symbol = _get_or_build_scene_item(item_id, "play '%s' in" % animation_name)
	
	if not item_symbol:
		return empty_action
	
	item_id = item_symbol.symbol_name
	
	if item_symbol.animation == animation_name:
		#print("Item '%s' is already doing '%s'" % [item_id, animation_name])
		return empty_action
	
	item_symbol.animation = animation_name
	
	if item_symbol.loaded and not item_symbol.disabled:
		var item = item_symbol.target
		assert(item == loaded_scene_items[item_id])

		if item.has_node("animation"):
			var animator: AnimationPlayer = item.get_node("animation")
			if animator.has_animation(animation_name):
				animator.play(animation_name)
			else:
				print("%s: animation '%s' not found" % [item_id, animation_name])
		else:
			print("%s: animation player not found" % item_id)
	
	return empty_action

func _command_set_tool(item_id: String, verb_name: String):
	var item_symbol = symbols.get_symbol_of_types(item_id, ["scene_item", "inventory_item_instance"], true)
	
	if not item_symbol.type:
		return empty_action
	
	item_id = item_symbol.symbol_name
	
	if item_symbol.type == "scene_item":
		if not item_symbol.loaded:
			print("Item '%s' can't be used as tool: isn't loaded" % item_id)
			return empty_action
		elif item_symbol.disabled:
			print("Item '%s' can't be used as tool: is disabled" % item_id)
			return empty_action
	
	_server_event("tool_set", [item_symbol.target, verb_name])
	
	return empty_action
	
func _command_debug(new_value_expression) -> Dictionary:
	var new_value = new_value_expression.evaluate(self)
	
	print("DEBUG: %s (type %s, class %s)" % [new_value, Grog._typestr(new_value), new_value.get_class() if typeof(new_value) == TYPE_OBJECT else "-"])
	
	return empty_action

func _command_teleport(item_id: String, to_node_named: String, opts: Dictionary) -> Dictionary:
	assert(_server_state == ServerState.RunningSequence)
	
	var item_symbol = symbols.get_symbol_of_types(item_id, ["player"], true)
	
	if not item_symbol.type:
		print("No actor '%s'" % item_id)
		return empty_action
	
	var item = item_symbol.target
	
	var to_node_symbol = symbols.get_symbol_of_types(to_node_named, ["scene_item"], false)
	
	var to_node
	
	if to_node_symbol == null:
		# absent
		if not current_room.has_node(to_node_named):
			print("Node '%s' not found" % to_node_named)
			return empty_action
		else:
			to_node = current_room.get_node(to_node_named)
	
	elif not to_node_symbol.type:
		# type mismatch
		print("Can't walk to an object of type '%s'" % symbols.get_symbol_type(to_node_named))
		return empty_action
	else:
		if not to_node_symbol.loaded:
			print("walk: item '%s' is not in current room" % to_node_named)
			return empty_action
		elif to_node_symbol.disabled:
			print("walk: item '%s' is disabled" % to_node_named)
			return empty_action
		else:
			to_node = to_node_symbol.target
		
	var target_position = to_node.position
	item.position = target_position
	
	if opts.has("angle"):
		var angle_option = opts["angle"]
		if typeof(angle_option) != TYPE_INT:
			print("Angle is of type %s" % Grog._typestr(angle_option))
		angle_option = int(angle_option)
		item.set_angle(angle_option)
	
	return empty_action

func _command_curtain_up():
	_server_event("curtain_up")
	
	return empty_action

func _command_curtain_down():
	_server_event("curtain_down")
	var duration = 1.0
	_is_skippable = false
	
	_skipped = false
	
	return { coroutine = _wait_coroutine(duration) }

#func _command_break():
#	print("Break is called")
#	return empty_action

# only called manually
func _command_intern_walk() -> Dictionary:
	return { coroutine = _intern_walk_coroutine() }

##############################

#	@CLIENT REQUESTS

func start_game_request(p_root_node: Node) -> bool:
	if _server_state != ServerState.Prepared:
		push_error("Invalid start_game request")
		return false
	
	root_node = p_root_node
	
	if player_resource:
		if player_resource.get_target():
			current_player = player_resource.get_target().instance()
			symbols.add_symbol("you", "player", current_player)
		else:
			print("No target scene in actor resource")
	
	# initialize grog game
	
	_set_state(ServerState.Initializing)
	
	if _run_compiled(_compiled_scripts[0], "init"):
		return true
	else:
		print("Couldn't run init script")
		return false
	
func skip_or_cancel_request():
	if _server_state == ServerState.RunningSequence and _is_skippable and not _skipped:
		_skipped = true
		return true
	elif _server_state == ServerState.Serving and _is_cancelable and not _canceled:
		# cancel current walking and clear _goal
		_canceled = true
		_goal = null
		
		_clear_aliases()
		
		return true
	else:
		return false
		
func go_to_request(target_position: Vector2):
	if not _input_enabled or not current_player:
		return
	
	if _server_state == ServerState.Ready or (_server_state == ServerState.Serving and _is_cancelable and not _canceled):
		pass
	else:
		# go_to request rejected
		return

	var origin_position = current_player.position
	
	var path = build_path(origin_position, target_position, false)
	
	if not path:
		if _server_state == ServerState.Serving:
			# cancel current walking and clear _goal
			_canceled = true
			_goal = null
		return
	
	_path_changed = true
	_walking_path = path
	_walking_subject = current_player
	_goal = null
	
	_clear_aliases()
	
	if _server_state == ServerState.Ready:
		var ok = _run_sequence([
			{
				type = "command",
				command = "intern_walk",
				params = [],
			}
		])
		
		if ok:
			# TODO cancelable is hardcoded to true
			_set_state(ServerState.Serving, false, true)
		else:
			print("Unexpected")
	
	# else it's already walking
		
func interact_request(item, trigger_name: String, tool_item = null):
	if not _input_enabled or not current_player:
		return
	
	if _server_state != ServerState.Ready and (_server_state != ServerState.Serving or not _is_cancelable or _canceled):
		# interact request rejected
		return
	
	var id = item.get_id()
	var item_symbol = symbols.get_symbol_of_types(id, ["scene_item", "inventory_item_instance"], true)
	
	if not item_symbol.type:
		print("No item %s" % id)
		return empty_action
	
	var is_scene_item
	if item_symbol.type == "scene_item":
		is_scene_item = true
		if not item_symbol.loaded:
			print("Can't interact with scene item '%s': it's not in this room" % id)
			return
		elif item_symbol.disabled:
			print("Can't interact with scene item '%s': it's disabled" % id)
			return
	else:
		is_scene_item = false
	
	var _sequence # : Dictionary or null
	if tool_item:
		_sequence = item.get_sequence_with_parameter(trigger_name, tool_item.get_key())
		if not _sequence:
			# get fallback
			_sequence = _compiled_scripts[0].get_sequence_with_parameter("fallback/" + trigger_name, tool_item.get_key())
	else:
		_sequence = item.get_sequence(trigger_name)
	
		if not _sequence:
			# get fallback
			_sequence = _compiled_scripts[0].get_sequence("fallback/" + trigger_name)
	
	if not _sequence:
		_sequence = { statements = [], telekinetic = true }

	_clear_aliases()
	
	symbols.set_alias("self", id)
	if tool_item:
		symbols.set_alias("tool", tool_item.get_id())
	
	_goal = { instructions = _sequence.statements, subject = current_player }
	
	var has_to_walk = is_scene_item and not _sequence.telekinetic
	var path
	
	if has_to_walk:
		var origin_position = current_player.position
		var target_position = item.get_interact_position()
		path = build_path(origin_position, target_position, false)
		
		if not path:
			has_to_walk = false
		# else execute as telekinetic
		# TODO should change angle though?
	
	if has_to_walk:
		_goal.angle = item.interact_angle
		
		_path_changed = true
		_walking_path = path
		_walking_subject = current_player
		
		if _server_state == ServerState.Ready:
			var ok = _run_sequence([
				{
					type = "command",
					command = "intern_walk",
					params = [],
				}
			])
			
			if ok:
				# TODO cancelable is hardcoded to true
				_set_state(ServerState.Serving, false, true)
			else:
				print("Unexpected")
		
		# else the state is Serving so the walking coroutine is active;
		# we just reconfigured walking parameters and set _path_changed,
		# so the walking coroutine should detect it and refresh the path
		
	else:
		if not is_scene_item and not _sequence.telekinetic:
			print("%s: sequences over inventory items can't be non-telekinetic." % trigger_name)
			print("Running as telekinetic anyways.")
		
		# Telekinetic sequence
		if _server_state == ServerState.Ready:
			# do it immediately
			_do_goal()
		else:
			# cancel current walking but don't clear _goal
			# it will be executed later
			_canceled = true
			
	
func stop_request():
	match _server_state:
		ServerState.Ready:
			assert(runner == null)
			_stop()
		ServerState.Serving, ServerState.RunningSequence:
			assert(runner != null)
			_set_state(ServerState.Stopping)
			runner.stop_asap()
		_:
			print("Ignoring stop request")

##############################

#	@PRIVATE


# Note that if item_id=self, you should correct it to match symbol.symbol_name.
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
		print("Can't %s '%s'; is %s instead of scene_item" % [debug_action_name, item_key, symbols.get_symbol_type(item_key)])
		return null
		
	else:
		# already present
		return symbol
	
func _intern_walk_coroutine():
	assert(_path_changed)
	var path
	
	while true:
		if _path_changed:
			path = PoolVector2Array(_walking_path)
			_path_changed = false
		
		if path.size() < 2:
			break
		
		var time = 0.0

		var origin: Vector2 = path[0]
		var destiny: Vector2 = path[1]

		var displacement = destiny - origin
		var distance2 = displacement.length_squared()
		var direction = displacement.normalized()
		var angle = _get_degrees(direction)

		_walking_subject.walk(angle)
		
		while true:
			
			if _canceled:
				# walk canceled in response to client
				_walking_subject.stop()
				return {} # returning a dict makes Runner cancel all remaining tasks
			elif _path_changed: # this allows to change path from outside (for rewalk from client)
				break
			
			time += yield()
			
			var step_distance = _walking_subject.walk_speed * time

			var target_point = origin + step_distance * direction
			if pow(step_distance, 2) >= distance2:
				_walking_subject.teleport(destiny)
				path.remove(0)
				break
			else:
				_walking_subject.teleport(target_point)
	
	_walking_subject.stop()
	
	return null

# Returns angle in degrees between 0 and 360
func _get_degrees(direction: Vector2) -> float:
	var radians_angle = direction.angle()

	var deg_angle = radians_angle * 180.0 / PI

	if deg_angle < 0:
		deg_angle += 360.0

	return deg_angle

func _do_goal():
	if _goal.has("angle"):
		_goal.subject.set_angle(_goal.angle)
	
	var ok = _run_sequence(_goal.instructions)
	
	if ok:
		_set_state(ServerState.RunningSequence)
	else:
		print("Unexpected")
	
	_goal = null

func _stop():
	_set_state(ServerState.Stopped)
	_free_all()
	_server_event("game_ended")

func _runner_over(status):
	runner = null
	match _server_state:
		ServerState.Stopping:
			if status != Runner.RunnerStatus.Stopped:
				print("Unexpected status %s; stopping anyways" % status)
			_stop()
			
		ServerState.Initializing:
			if _run_compiled(_compiled_scripts[_game_start_param], "start"):
				_set_state(ServerState.RunningSequence)
				_server_event("game_started", [current_player])
			else:
				print("Couldn't run starting script")
		
		ServerState.RunningSequence:
			if status != Runner.RunnerStatus.Ok:
				print("Unexpected status %s; getting ready" % status)
			
			_set_state(ServerState.Ready)
			
			_clear_aliases()
			
		ServerState.Serving:
			if status == Runner.RunnerStatus.Canceled:
				assert(_canceled)
			elif status != Runner.RunnerStatus.Ok:
				print("Unexpected status %s; getting ready" % status)
			
			_set_state(ServerState.Ready)
			
			if _goal != null:
				assert(not _canceled)
				#TODO check it's in goal place?
				_do_goal()
		_:
			print("_runner_over: unexpected state %s" % _server_state)
	
func _server_event(event_name: String, args: Array = []):
	#print("SERVER EVENT '%s'" % event_name)
	emit_signal("game_server_event", event_name, args)

func _wait_coroutine(delay_seconds: float, and_then = null):
	var elapsed = 0.0

	while elapsed < delay_seconds:
		if _skipped:
			assert(_is_skippable)
			_skipped = false
			break
		elapsed += yield()

	_server_event("wait_ended")
	
	while and_then:
		and_then = and_then.resume(yield())

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

func _run_sequence(instructions: Array) -> bool:
	assert(runner == null)
	assert(_server_state == ServerState.Ready or _server_state == ServerState.Initializing)
	
	runner = Runner.new()
	
	var is_running = runner.run(instructions, self)
	
	if not is_running:
		print("Couldn't run")
		runner = null
		return false
	else:
		return true
	
func _run_compiled(compiled_script, sequence_name: String) -> bool:
	if compiled_script.has_sequence(sequence_name):
		var sequence = compiled_script.get_sequence(sequence_name)
		
		return _run_sequence(sequence.statements)
	else:
		print("Sequence '%s' not found" % sequence_name)
		return false

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

func build_path(origin_position: Vector2, target_position: Vector2, is_global):
	var nav : Navigation2D = current_room.get_navigation()
	if not nav:
		return null
	
	if is_global:
		target_position = target_position - nav.global_position
	
	target_position = nav.get_closest_point(target_position)
	
	var distance = origin_position.distance_to(target_position)
	
	var close_enough = distance <= interact_distance_threshold
	
	if close_enough:
		return []
	
	var path: PoolVector2Array = nav.get_simple_path(origin_position, target_position)
	
	return path

##############################

#	@GLOBAL STATE ACCESS

func get_state():
	return _server_state

func is_playing():
	return get_state() in [ServerState.Ready, ServerState.RunningSequence, ServerState.Serving]

func get_value(var_name: String):
	var symbol = symbols.get_symbol(var_name)
	
	if symbol == null:
		# absent
		print("Global variable or symbol '%s' not found" % var_name) # TODO level
		return 0 # absent symbol defaults to zero
	
	match symbol.type:
		"global_variable":
			return symbol.target
		
		"inventory_item":
			return symbol.amount # instances.size()
		
		"inventory_item_instance":
			return symbol.target.get_key()
			
		"scene_item":
			if symbol.disabled:
				return "disabled"
			else:
				return symbol.animation
		_:
			print("Trying to dereference symbol '%s' of type '%s'" % [var_name, symbol.type])
			return false
	
func _set_state(new_state, skippable=false, cancelable=false):
	#print("\t\t\t%s -> %s" % [ServerState.keys()[_server_state], ServerState.keys()[new_state]])
	_server_state = new_state
	_is_skippable = skippable
	_skipped = false
	_is_cancelable = cancelable
	_canceled = false

#func _set_tool(item_symbol, verb_name: String):
#	current_tool_symbol = item_symbol
#	current_tool_verb = verb_name
#
#	_server_event("tool_set", [item_symbol.target, verb_name])

func _clear_aliases():
	if symbols.has_alias("self"):
		symbols.remove_alias("self")
	if symbols.has_alias("tool"):
		symbols.remove_alias("self")

func is_navigable(point: Vector2):
	if not current_room:
		return false
	if point.x < 0 or point.x > 1920:
		return false
	if point.y < 0 or point.y > 1080:
		return false
	
	var nav : Navigation2D = current_room.get_navigation()
	
	if not nav:
		return false
	
	return point.is_equal_approx(nav.get_closest_point(point))
