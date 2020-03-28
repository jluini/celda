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
	
func coroutine(sequence: Array):
	status = RunnerStatus.Running
	
	#var elapsed_time = 0
	var i = 0
	
	_stopped = false
	
	var delta = yield()
	
	while i < sequence.size():
		var instruction = sequence[i]
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
				
				var method_name = "_run_" + cmd
				
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
					
					if typeof(command_termination) != TYPE_OBJECT or command_termination.get_class() != "GDScriptFunctionState":
						print("%s: invalid coroutine (%s)" % [method_name, command_termination])
					
					else:
						while true:
							if _stopped:
								print("Stopped")
								status = RunnerStatus.Stopped
								return null
							
							delta = yield()
							#elapsed_time += delta
							command_termination = command_termination.resume(delta)
							
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
							
							#if typeof(command_termination) == TYPE_DICTIONARY:
							#	status = RunnerStatus.Canceled
							#	return null
							
							

					
					# end while
				# end if (no coroutine so we continue)
			
			"if":
				if not instruction.has("condition") or not instruction.has("main_branch"):
					end_with_error("Invalid if: %s" % instruction)
					return null
				
				var condition = instruction.condition
				var main_branch = instruction.main_branch
				var else_branch = instruction.else_branch if instruction.has("else_branch") else []
				
				var result = condition.evaluate(output)
				
				var branch: Array = main_branch if result else else_branch
				
				if branch.size() > 0:
					for j in range(branch.size()):
						sequence.insert(i, branch[branch.size() - 1 - j])
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
