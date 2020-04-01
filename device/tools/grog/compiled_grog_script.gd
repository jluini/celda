
class_name CompiledGrogScript

var empty_sequence = { statements=[], telekinetic=true }

var is_valid
var errors = []

var _sequences = {}

#	@CREATE

func _init():
	is_valid = true

func add_sequence(sequence_name: String, sequence: Dictionary):
	if has_sequence(sequence_name):
		push_error("Already has sequence '%s'" % sequence_name)
		return
	
	if not sequence or typeof(sequence) != TYPE_DICTIONARY or not sequence.has("statements") or not sequence.has("telekinetic"):
		print("Error grave: %s" % str(sequence))
		return
	
	_sequences[sequence_name] = sequence

#	@USE

func has_sequence(sequence_name: String):
	if not is_valid:
		return false
	
	return _sequences.has(sequence_name) and not _sequences[sequence_name].has("pattern")

func get_sequence(sequence_name: String):
	if not is_valid:
		return null
	elif not has_sequence(sequence_name):
		return null
	
	return _sequences[sequence_name]

func get_sequence_with_parameter(sequence_name: String, param: String):
	if not _sequences.has(sequence_name):
		#print("Parameterized sequence '%s' not present" % sequence_name)
		return null
	
	var ret = _sequences[sequence_name]
	if not ret.has("pattern"):
		return null
	
	var escaped_pattern = ret.pattern.replace("/", "\\/")
	escaped_pattern = escaped_pattern.replace("*", ".*")
	
	var regex = RegEx.new()
	regex.compile("^" + escaped_pattern + "$")
	
	if not regex.search(param):
		return null
	
	return ret
	
func add_error(new_error):
	errors.append(new_error)
	is_valid = false

func print_errors():
	for i in range(errors.size()):
		print(errors[i])
		
