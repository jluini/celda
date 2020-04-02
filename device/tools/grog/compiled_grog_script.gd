
class_name CompiledGrogScript

var empty_sequence = { statements=[], telekinetic=true }

var is_valid
var errors = []

var _sequences = {}
var _parameterized_sequences = {}

#	@CREATE

func _init():
	is_valid = true

func add_sequence_with_parameter(sequence_name: String, pattern: String, sequence: Dictionary):
	if not _parameterized_sequences.has(sequence_name):
		_parameterized_sequences[sequence_name] = []
	
	for i in range(_parameterized_sequences[sequence_name].size()):
		var s = _parameterized_sequences[sequence_name][i]
		if s.pattern == pattern:
			print("Already has a sequence '%s' with parameter pattern '%s'" % [sequence_name, pattern])
	
	if not sequence or typeof(sequence) != TYPE_DICTIONARY or not sequence.has("statements") or not sequence.has("telekinetic"):
		print("Error grave2: %s" % str(sequence))
		return
	
	_parameterized_sequences[sequence_name].append({
		pattern = pattern,
		sequence = sequence
	})
	
func add_sequence(sequence_name: String, sequence: Dictionary):
	if has_sequence(sequence_name):
		push_error("Already has sequence '%s'" % sequence_name)
		return
	
	if not sequence or typeof(sequence) != TYPE_DICTIONARY or not sequence.has("statements") or not sequence.has("telekinetic"):
		print("Error grave1: %s" % str(sequence))
		return
	
	_sequences[sequence_name] = sequence

#	@USE

func has_sequence(sequence_name: String):
	if not is_valid:
		return false
	
	return _sequences.has(sequence_name)

func get_sequence(sequence_name: String):
	if not is_valid:
		return null
	elif not has_sequence(sequence_name):
		return null
	
	return _sequences[sequence_name]

func get_sequence_with_parameter(sequence_name: String, param: String):
	if not _parameterized_sequences.has(sequence_name):
		#print("Parameterized sequence '%s' not present" % sequence_name)
		return null
	
	var pss = _parameterized_sequences[sequence_name]
	
	for ps in pss:
		if not ps.has("pattern"):
			print("Missing pattern in parameterized sequence %s" % sequence_name)
			return null
		
		var pattern = ps.pattern
		var escaped_pattern = pattern.replace("/", "\\/")
		escaped_pattern = escaped_pattern.replace("*", ".*")
		
		var regex = RegEx.new()
		regex.compile("^" + escaped_pattern + "$")
		
		if regex.search(param):
			return ps.sequence
		#else:
			#print("Doesn't match %s %s" % [escaped_pattern, param])
	
	return null
	
func add_error(new_error):
	errors.append(new_error)
	is_valid = false

func print_errors():
	for i in range(errors.size()):
		print(errors[i])
		
