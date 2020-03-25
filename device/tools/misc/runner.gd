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
	
	var _ret = grog.connect("grog_update", self, "grog_update")
	return true
	
func coroutine(sequence):
	status = RunnerStatus.Running
	
	#var elapsed_time = 0
	var num_instructions = sequence.size()
	var i = 0
	
	_stopped = false
	
	var delta = yield()
	
	while i < num_instructions:
		var instruction = sequence[i]
		i += 1
		
		if not typeof(instruction) == TYPE_DICTIONARY or not instruction.has("command") or not instruction.has("params"):
			end_with_error("Invalid instruction: %s" % instruction)
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
		
		if command_result.has("coroutine"):
			var command_termination = command_result.coroutine
			
			while command_termination:
				if _stopped:
					status = RunnerStatus.Canceled
					return null
				
				delta = yield()
				#elapsed_time += delta
				command_termination = command_termination.resume(delta)
			
	
	status = RunnerStatus.Ok
	return null

#######################

func stop_asap():
	_stopped = true

#######################

func grog_update(delta):
	if _routine:
		_routine = _routine.resume(delta)
		
		if not _routine:
			#print("Routine is over: %s" % RunnerStatus.keys()[status])
			
			output._runner_over(status)
			
func end_with_error(msg):
	status = RunnerStatus.Error
	message = msg
	print(msg)

#######################

#func run_raw(inner_coroutine, output) -> bool:
#	if not __init(output):
#		return false
#
#	_routine = coroutine_raw(inner_coroutine)
#
#	return true
#
#func coroutine_raw(inner_coroutine):
#	status = RunnerStatus.Running
#
#	var elapsed_time = 0
#
#	while inner_coroutine:
#		var delta = yield()
#		elapsed_time += delta
#		inner_coroutine = inner_coroutine.resume(delta)
#
#	status = RunnerStatus.Ok
#	return null
