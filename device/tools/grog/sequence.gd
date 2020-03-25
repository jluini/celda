class_name Sequence

var _instructions: Array
var _telekinetic: bool

func _init(p_instructions, p_telekinetic = true):
	_instructions = p_instructions
	_telekinetic = p_telekinetic

func get_instructions():
	return _instructions

func is_telekinetic() -> bool:
	return _telekinetic

func in_context(context: Dictionary) -> Array:
	var ret: Array = _instructions.duplicate(true)
	
	_contextualize(ret, context)
	
	return ret

func _contextualize(ret: Array, context: Dictionary):
	for i in range(ret.size()):
		var instruction = ret[i]
		
		if instruction.type == grog.LineType.Command:
			var command = instruction.command
			var requirements = grog.commands[command]
			
			if requirements.subject == grog.SubjectType.None:
				continue
			
			var current_subject = instruction.params[0]
			
			if context.has(current_subject):
				# does the replacement
				var new_subject = context[current_subject]
				instruction.params[0] = new_subject
		
		elif instruction.type == grog.LineType.If:
			_contextualize(instruction.main_branch, context)
			if instruction.has("else_branch"):
				_contextualize(instruction.else_branch, context)
		
		else:
			push_error("Unexpected line type %s" % grog.LineType.keys()[instruction.type])
	
	return ret
