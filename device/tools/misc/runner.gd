class_name Runner

enum RunnerStatus {
	Start,
	Running,
	Ok,
	Canceled,
	Error
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
				
				var command_result = output.callv(method_name, params)
				
				if typeof(command_result) != TYPE_DICTIONARY:
					end_with_error("Command '%s': invalid result of execution" % method_name)
					return null
				
				if command_result.has("coroutine"):
					var command_termination = command_result.coroutine
					
					while command_termination:
						if _stopped:
							status = RunnerStatus.Canceled
							return null
						
						delta = yield()
						#elapsed_time += delta
						command_termination = command_termination.resume(delta)
					
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
