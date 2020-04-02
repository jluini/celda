class_name Runner

enum RunnerStatus {
	Start,
	Running,
	Ok,
	Canceled,
	Error,
	Stopped
}

var status = RunnerStatus.Start
var message: String = ""

var output

var _routine
var _stopped: bool

#
# output must have:
#     _runner_over(status)
#

func run(p_sequence: Array, p_output) -> bool:
	if not __init(p_output):
		return false
	
	_routine = coroutine(p_sequence)
	
	return true

func __init(p_output) -> bool:
	if status != RunnerStatus.Start:
		print("Can't run again")
		return false
	
	output = p_output
	
	return true
	
func coroutine(instructions: Array):
	status = RunnerStatus.Running
	
	#var elapsed_time = 0
	var i = 0
	
	_stopped = false
	
	var stack = []
	
	var delta = yield()
	
	while true:
		while i >= instructions.size() and stack.size() > 0:
				# this branch is over
				var previous_level = stack.pop_back()
				instructions = previous_level.instructions
				i = previous_level.index
		
		if i >= instructions.size(): # now stack.size() == 0
			# whole sequence is over
			break
		
		var instruction = instructions[i]
		i += 1
		
		if not typeof(instruction) == TYPE_DICTIONARY:
			end_with_error("Invalid instruction type: %s" % instruction)
			return null
		
		match instruction.type:
			"command":
				if not instruction.has("command") or not instruction.has("params"):
					end_with_error("Invalid command: %s" % instruction)
					return null
				
				var cmd = instruction.command
				var params = instruction.params
				
				var method_name = "_command_" + cmd
				
				if not output.has_method(method_name):
					var msg = "Execution target has no method '%s'" % method_name
					end_with_error(msg)
					return null
				
				#print("%s %s" % [cmd, params])
				
				var command_result = output.callv(method_name, params)
				
				if typeof(command_result) != TYPE_DICTIONARY:
					end_with_error("Command '%s': invalid result of execution" % method_name)
					return null
				
				if command_result.has("stop"):
					if command_result.stop == true:
						status = RunnerStatus.Stopped
						return null # stops coroutine
					else:
						print("Warning, stop in result but it's not true; doing nothing'")
				
				if command_result.has("coroutine"):
					var command_termination = command_result.coroutine
					
					while true:
						if _stopped:
							status = RunnerStatus.Stopped
							return null
						
						if command_termination == null:
							# ended ok
							break
						elif typeof(command_termination) == TYPE_OBJECT and command_termination.get_class() == "GDScriptFunctionState":
							if not command_termination.is_valid(true):
								print("Invalid coroutine")
								break
							# continue
						elif typeof(command_termination) == TYPE_DICTIONARY:
							status = RunnerStatus.Canceled
							return null
						else:
							print("Invalid result %s" % command_termination)
							end_with_error("Invalid coroutine execution result")
							return null
						
						delta = yield()
						#elapsed_time += delta
						command_termination = command_termination.resume(delta)
					
					# end while
				# end if (no coroutine so we continue)
			
			"if":
				if not instruction.has("main_branches") or instruction.main_branches.size() < 1:
					end_with_error("Invalid if: %s" % instruction)
					return null
				
				var branch_to_execute = null
				
				for i in range(instruction.main_branches.size()):
					var branch = instruction.main_branches[i]
					
					var result = branch.condition.evaluate(output)
					if typeof(result) != TYPE_BOOL:
						var original_result = result
						result = true if result else false
						print("Evaluating %s (%s) as bool (%s)" % [original_result, output._typestr(original_result), result])
				
					if result:
						branch_to_execute = branch.statements
						break
				
				if branch_to_execute == null and instruction.has("else_branch"):
					branch_to_execute = instruction.else_branch
				
				if branch_to_execute != null and branch_to_execute.size() > 0:
					stack.push_back({
						instructions = instructions,
						index = i
					})
					instructions = branch_to_execute
					i = 0
			_:
				print("Unexpected instruction type '%s'" % instruction.type)
		
		# end match line type
	# end while more instructions
	
	status = RunnerStatus.Ok
	return null

#######################

func stop_asap():
	_stopped = true

#######################

func update(delta):
	if _routine:
		_routine = _routine.resume(delta)
		
		if not _routine:
			output._runner_over(status)
			
func end_with_error(msg):
	status = RunnerStatus.Error
	message = msg
	print(msg)
