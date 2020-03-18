
# server to client signals
signal grog_server_event

var data
var globals

var pending_actions : Array

enum GameState { Idle, DoingSomething}
var state = GameState.Idle
var total_time

var become_idle_when = null

var routine = null

func start_game(game_data: Resource):
	data = game_data
	
	globals = {}
	
	pending_actions = []
	total_time = 0
	routine = coroutine()

func process(delta):
	total_time += delta
	
	if routine:
		routine = routine.resume()


func coroutine():
	while true:
		state = GameState.Idle
		yield()
		
		while not pending_actions:
			yield()
		
		# there are pending actions
		state = GameState.DoingSomething
		
		while true:
			var next_action = pending_actions.pop_front()
			
			var is_blocking = run_instruction(next_action)
	
			if is_blocking:
				# Start blocking action
				while true:
					yield()
					var current_time = get_current_time()
					if become_idle_when <= current_time:
						break
				# End of blocking action
				
			if not pending_actions:
				server_event("ready")
				break
		
		# it's ready again
#	if state == GameState.DoingSomething:
#		var current_time = get_current_time()
#		if become_idle_when <= current_time:
#
	
	
	
#	if state == GameState.Idle and pending_actions:
#		var next = pending_actions.pop_front()
#
#		var is_blocking = run_instruction(next)
#
#	elif state == GameState.DoingSomething:
#		if become_idle_when != null:
#			var current_time = get_current_time()
#			if become_idle_when <= current_time:
#				state = GameState.Idle
#				become_idle_when = null
		


func run_instruction(inst: Dictionary) -> bool:
	if inst.subject:
		print("Unknown subject '%s'" % inst.subject)
		return false
	
	match inst.command:
		"load_room":
			if inst.params.size() < 1:
				print("One parameter needed for load_room")
				return false
			
			var room_name = inst.params[0]
			var actor_name = ""
			if inst.params.size() >= 2:
				var actor_param = inst.params[1]
				if actor_param.begins_with("player="):
					actor_name = actor_param.substr(len("player="))

			var room = load_room(room_name, actor_name)
			
			if not room:
				print("Couldn't load room '%s'" % room_name)
				return false
		"show_controls":
			server_event("show_controls")
		"hide_controls":
			server_event("hide_controls")
		"wait":
			if inst.params.size() < 1:
				print("One parameter needed for wait")
				return false
			
			var time_param = inst.params[0]
			var delay_seconds = float(time_param)
			
			server_event("start_waiting", [delay_seconds])
			
			wait(delay_seconds)
			return true
			
		"say":
			if inst.params.size() < 1:
				print("One parameter needed for say")
				return false
			
			# TODO make this configurable and skipping
			var delay_seconds = 1.0
			
			var speech = inst.params[0]
			server_event("say", [speech, delay_seconds])
			
			wait(delay_seconds)
			return true
		
		_:
			print("Unknown instruction '%s'" % inst.command)
			return false
	return false

func wait(delay_seconds):
	state = GameState.DoingSomething
	
	# TODO use Timer's instead of polling
	var current = get_current_time()
	become_idle_when = within_seconds(current, delay_seconds)

func run_script(script_name: String, routine_name: String):
	var script_resource = get_script_resource(script_name)
	
	if not script_resource:
		print("No script '%s'" % script_name)
		return
	
	var compiled_script = grog.compile(script_resource)
	if not compiled_script.is_valid:
		print("Script '%s' is invalid")
		
		compiled_script.print_errors()
		return
	
	run_compiled(compiled_script, routine_name)

func run_compiled(compiled_script: CompiledGrogScript, routine_name: String):
	if compiled_script.has_routine(routine_name):
		var instructions = compiled_script.get_routine(routine_name)

		push_actions(instructions)
	else:
		print("Routine '%s' not found" % routine_name)

func push_actions(action_list):
	for a in action_list:
		pending_actions.push_back(a)

func load_room(room_name: String, actor_name: String) -> Node:
	var room_resource = get_room(room_name)
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
	
	server_event("load_room", [room])
	
	if actor_name:
		var actor_resource = get_actor(actor_name)
		if not actor_resource:
			print("No actor '%s'" % actor_name)
			return null
		
		if not actor_resource.actor_scene:
			print("No actor_scene in actor '%s'" % actor_name)
			return null
		
		var actor = actor_resource.actor_scene.instance()
		
		if not room:
			push_error("Couldn't load actor '%s'"  % actor_name)
			return null
		
		server_event("load_actor", [actor])
	
	return room

func server_event(event_name: String, args: Array = []):
	emit_signal("grog_server_event", event_name, args)

#### Finding resources

func get_room(room_name):
	return get_resource_in(data.get_all_rooms(), room_name)

func get_actor(actor_name):
	return get_resource_in(data.get_all_actors(), actor_name)

func get_script_resource(script_name):
	return get_resource_in(data.get_all_scripts(), script_name)

func get_resource_in(list, elem_name):
	for i in range(list.size()):
		var elem = list[i]
		
		if elem.get_name() == elem_name:
			return elem
	return null

####### Time

func get_current_time():
	return OS.get_ticks_msec()

func within_seconds(current_time, seconds):
	return current_time + 1000 * seconds
