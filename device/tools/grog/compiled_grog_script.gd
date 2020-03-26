
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
	
	return _sequences.has(sequence_name)

func get_sequence(sequence_name: String) -> Dictionary:
	if not is_valid:
		return empty_sequence
	elif not has_sequence(sequence_name):
		print("Sequence '%s' not present" % sequence_name)
		return empty_sequence
	
	return _sequences[sequence_name]

func add_error(new_error):
	errors.append(new_error)
	is_valid = false

func print_errors():
	for i in range(errors.size()):
		print(errors[i])
		
