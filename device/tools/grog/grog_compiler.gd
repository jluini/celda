class_name GrogCompiler

# Compiler patterns
const sequence_header_regex_pattern = "^\\:([a-zA-Z0-9\\.\\-\\_\\ \\#]+)$"

const command_regex_pattern = "^([a-z0-9\\-\\_\\/]*)\\.([a-z\\_]+)$"

const float_regex_pattern = "^\\ *([0-9]+|[0-9]*\\.[0-9]+)\\ *$"

const TOKEN_RAW = "raw"
const TOKEN_QUOTED = "quoted"

#	@PUBLIC

func compile(script: Resource) -> CompiledGrogScript:
	return compile_text(script.get_code())

func compile_text(code: String) -> CompiledGrogScript:
	var compiled_script = CompiledGrogScript.new()
	
	if code.find("\r") != -1:
		print("Warning: unexpected carriage returns in code")
		print("removing them...")
		
		code = code.replace("\r", "")
	
	var raw_lines: Array = code.split("\n")
	
	var tokenized_lines = tokenize_lines(compiled_script, raw_lines)
	
	if not compiled_script.is_valid:
		return compiled_script
	
	identify_lines(compiled_script, tokenized_lines)
	
	if not compiled_script.is_valid:
		return compiled_script
	
	compile_lines(compiled_script, tokenized_lines)
	
	return compiled_script

func compile_lines(compiled_script: CompiledGrogScript, lines: Array) -> void:
	var num_lines = lines.size()
	
	var i = 0
	
	while i < num_lines:
		var current_line = lines[i]
		var line_num = current_line.line_number
		i += 1
		
		# expecting a header ":look TK" or ":start"
		
		if current_line.type != grog.LineType.Header:
			# this can only happen at the start of the script
			compiled_script.add_error("Expecting sequence header (line %s)" % line_num)
			return
		
		if current_line.indent_level != 0:
			compiled_script.add_error("Sequence header can't be indented (line %s)" % line_num)
			return
		
		# reading sequence header line
		
		var sequence_trigger: String = current_line.sequence_trigger
		
		if compiled_script.has_sequence(sequence_trigger):
			compiled_script.add_error("Duplicated trigger '%s'" % sequence_trigger)
			return
		
		var params: Array = current_line.params
		
		var telekinetic = false
		
		# doing this because currently 'telekinetic' is the only sequence parameter
		if params:
			var param = params[0].content.to_lower()
			if param == "telekinetic" or param == "tk":
				telekinetic = true
				params.pop_front()
		
		if params.size() > 0:
			for j in range(params.size()):
				var param = params[j]
				compiled_script.add_error("Sequence '%s': invalid param '%s' (line %s)" % [sequence_trigger, token_str(param), line_num])
				return
		
		var stack = []
		var statements: Array = []
		
		var level = 0
		
		while true:
			var more_statements = i < num_lines and lines[i].type != grog.LineType.Header
			
			var current_level
			
			if more_statements:
				current_line = lines[i]
				line_num = current_line.line_number
				i += 1
				
				current_level = current_line.indent_level
				if current_level > level:
					compiled_script.add_error("Invalid indentation (line %s)" % line_num)
					return
			else:
				current_level = 0
			
			if current_level < level:
				var diff_level = level - current_line.indent_level
				
				for _j in range(diff_level):
					var previous_level = stack.pop_back()
					
					var current_if = previous_level.back()
					
					if current_if.has("main_branch"):
						assert(not current_if.has("else_branch"))
						current_if.else_branch = statements
					else:
						current_if.main_branch = statements
					
					level -= 1
					statements = previous_level
			
			if not more_statements:
				break
			
			match current_line.type:
				grog.LineType.If:
					statements.append({
						type = grog.LineType.If,
						condition = GlobalVarIsTrueCondition.new(current_line.var_name),
					})
					
					stack.push_back(statements)
					statements = []
					level += 1
					
				grog.LineType.Else:
					if statements.size() == 0:
						compiled_script.add_error("Unexpected 'else' block (line %s)" % line_num)
						return

					var current_if = statements.back()
					if current_if.type != grog.LineType.If or current_if.has("else_branch"):
						compiled_script.add_error("Unexpected 'else' block (line %s)" % line_num)
						return
					
					stack.push_back(statements)
					statements = []
					level += 1
					
				grog.LineType.Command:
					var subject: String = current_line.subject
					var command: String = current_line.command
					params = current_line.params
					
					if not grog.commands.has(command):
						compiled_script.add_error("Unknown command '%s' (line %s)" % [command, line_num])
						return
					
					var command_requirements = grog.commands[command]
					
					match command_requirements.subject:
						grog.SubjectType.None:
							if subject:
								compiled_script.add_error("Command '%s' can't has subject (line %s)" % [command, line_num])
								return
						grog.SubjectType.Required:
							if not subject:
								compiled_script.add_error("Command '%s' must have a subject (line %s)" % [command, line_num])
								return
						grog.SubjectType.Optional:
							pass
						_:
							compiled_script.add_error("Grog error: unexpected subject type %s" % grog.SubjectType.keys()[command_requirements.subject])
							return
					
					var total = params.size()
					var required = command_requirements.required_params
					var num_required = required.size()
					
					if total < num_required:
						compiled_script.add_error("Command '%s' needs at least %s parameters (line %s)" % [command, num_required, line_num])
						return
					
					var final_params = []
					
					if command_requirements.subject != grog.SubjectType.None:
						final_params.append(subject)
					
					# checks and pushes required parameters and removes them from params list
					for j in range(num_required):
						var param_token = params.pop_front() # removes first param
						
						var param
						
						match required[j]:
							grog.ParameterType.StringType:
								param = param_token.content
							grog.ParameterType.StringTokenType:
								param = param_token
							grog.ParameterType.FloatType:
								var float_str = param_token.content
								if not float_str_is_valid(float_str):
									compiled_script.add_error("Token '%s' is not a valid float parameter (line %s)" % [float_str, line_num])
									return
								param = float(param_token.content)
							grog.ParameterType.BooleanType:
								var option_raw_value = param_token.content
								if option_raw_value.to_lower() == "false":
									param = false
								elif option_raw_value.to_lower() == "true":
									param = true
								else:
									compiled_script.add_error("Option '%s' is not a valid boolean (line %s)" % [option_raw_value, line_num])
									return
							_:
								compiled_script.add_error("Grog error: unexpected parameter type %s" % grog.ParameterType.keys()[required[j]])
								return
						
						final_params.append(param)
					
					var options = {}
					
					var named: Array = command_requirements.named_params
					var num_named = named.size()
					
					for j in range(num_named):
						var named_option: Dictionary = named[j]
						
						var option_name: String = named_option.name
						var option_type = named_option.type
						var is_required: bool = named_option.required
						
						var option_values: Array = extract_option_values(params, option_name)
						
						match option_values.size():
							0:
								if is_required:
									compiled_script.add_error("Command '%s' requires option '%s' (line %s)" % [command, option_name, line_num])
									return
		
							1:
								var option_raw_value: String = option_values[0]
								var option_value
								match option_type:
									grog.ParameterType.StringType:
										option_value = option_raw_value
									grog.ParameterType.FloatType:
										if not float_str_is_valid(option_raw_value):
											compiled_script.add_error("Option '%s' is not a valid float (line %s)" % [option_raw_value, line_num])
											return
										
										option_value = float(option_raw_value)
										
									grog.ParameterType.BooleanType:
										if option_raw_value.to_lower() == "false":
											option_value = false
										elif option_raw_value.to_lower() == "true":
											option_value = true
										else:
											compiled_script.add_error("Option '%s' is not a valid boolean (line %s)" % [option_raw_value, line_num])
											return
										
									_:
										compiled_script.add_error("Grog error: unexpected option type %s" % option_type)
										return
								
								options[option_name] = option_value
							_:
								compiled_script.add_error("Duplicated option '%s' (line %s)" % [option_name, line_num])
								return
						
					if params.size() > 0:
						for j in range(params.size()):
							var param = params[j]
							compiled_script.add_error("%s: invalid param '%s' (line %s)" % [command, token_str(param), line_num])
							return
					
					# saves array of options parameters
					final_params.append(options)
					
					statements.append({
						type = grog.LineType.Command,
						command = command,
						params = final_params
					})
			# end match
		
		# end while (until next sequence or end of script)
		
		var sequence = Sequence.new(statements, telekinetic)
		
		compiled_script.add_sequence(sequence_trigger, sequence)
		
	#return compiled_script

func extract_option_values(params: Array, option_name: String) -> Array:
	var ret = []
	for i in range(params.size()):
		var index = i - ret.size()
		var param_token: Dictionary = params[index]
		var param_content: String = param_token.content
		var prefix = option_name + "="
		
		if param_token.type == TOKEN_RAW and param_content.begins_with(prefix) and param_content.length() > prefix.length():
			ret.append(param_content.substr(prefix.length()))
			params.remove(index)
			
	return ret

func identify_lines(compiled_script: CompiledGrogScript, lines: Array) -> void:
	for i in range(lines.size()):
		identify_line(compiled_script, lines[i])

func identify_line(compiled_script: CompiledGrogScript, line: Dictionary) -> void:
#	if line.indent_level != 0:
#		compiled_script.add_error("Indentation levels not implemented (line %s)" % line.line_number)
#		return
	
	var first_token: Dictionary = line.tokens[0]
	
	if first_token.type != TOKEN_RAW:
		compiled_script.add_error("Invalid first token %s (line %s)" % [token_str(first_token), line.line_number])
		return
	
	var num_tokens = line.tokens.size()
	var first_content: String = first_token.content
	
	if first_content.begins_with(":"):
		# it's a sequence header
		var result = sequence_header_regex().search(first_content)
		if not result:
			compiled_script.add_error("Sequence name '%s' is not valid (line %s)" % [first_content, line.line_number])
			return
		
		line.type = grog.LineType.Header
		line.sequence_trigger = result.strings[1]
		
	elif first_content == "if":
		#it's an if block
		if num_tokens < 2 or num_tokens > 3 or line.tokens[1].type != TOKEN_RAW:
			compiled_script.add_error("Invalid if (line %s)" % line.line_number)
			return
		
		var var_name = line.tokens[1].content
		
		if num_tokens == 3:
			if line.tokens.type != TOKEN_RAW or line.tokens[2].content != ":":
				compiled_script.add_error("Invalid if (line %s)" % line.line_number)
				return
		else:
			if var_name.length() < 2 or not var_name.ends_with(":"):
				compiled_script.add_error("Invalid if (line %s)" % line.line_number)
				return
			
			var_name = var_name.substr(0, var_name.length() - 1)
		
		var reg = build_regex("^[a-z0-9\\-\\_]+(\\/[a-z0-9\\-\\_]+)*$")
		var res = reg.search(var_name)
		if not res:
			compiled_script.add_error("Invalid if (line %s)" % line.line_number)
			return
			
		#print("Funciono! '%s'" % var_name)
		
		line.type = grog.LineType.If
		line.var_name = var_name
	
	elif first_content == "else:":
		if num_tokens != 1:
			compiled_script.add_error("Invalid else (line %s)" % line.line_number)
			return
		
		line.type = grog.LineType.Else
		
	else:
		# it's a command
		var result = command_regex().search(first_content)
		if not result:
			compiled_script.add_error("Command '%s' is not valid (line %s)" % [first_content, line.line_number])
			
			if first_content.find(".") == -1:
				if grog.commands.has(first_content):
					compiled_script.add_error("Did you mean .%s?" % first_content)
				else:
					compiled_script.add_error("Did you forget the leading dot?")
				
			return
			
		# TODO do a basic check over parameters?
		
		line.type = grog.LineType.Command
		line.subject = result.strings[1]
		line.command = result.strings[2]
	
	var params: Array = line.tokens
	params.pop_front()
	line.params = params
	
func tokenize_lines(compiled_script: CompiledGrogScript, raw_lines: Array) -> Array:
	var ret = []
	
	for i in range(raw_lines.size()):
		var raw_line = raw_lines[i]
		
		var line = { line_number = i + 1, raw = raw_line }
		
		tokenize(compiled_script, line)
		
		if not compiled_script.is_valid:
			return []
			
		if not line.blank:
			ret.append(line)
	
	return ret

func tokenize(compiled_script: CompiledGrogScript, c_line: Dictionary) -> void:
	var raw_line = c_line.raw
	
	var indent_level = number_of_leading_tabs(raw_line)
	var line_content = raw_line.substr(indent_level)
	
	var tokens = get_tokens(compiled_script, line_content, c_line.line_number)
	
	if not compiled_script.is_valid:
		# Invalid line
		return
		
	c_line.blank = tokens.size() == 0
	
	if not c_line.blank:
		c_line.indent_level = indent_level
		c_line.tokens = tokens
		

enum TokenizerState {
	WaitingNextToken,
	WaitingSpace,
	ReadingToken,
	ReadingQuotedToken,
	ReadingEscapeSequence
}

# TODO build strings efficiently
func get_tokens(compiled_script: CompiledGrogScript, line: String, line_number: int) -> Array:
	var tokens = []
	
	var current_token: Dictionary
	var state = TokenizerState.WaitingNextToken
	
	for i in range(line.length()):
		var c = line[i]
		
		match state:
			TokenizerState.WaitingNextToken:
				if c == " ":
					pass
				elif c == "\"":
					state = TokenizerState.ReadingQuotedToken
					current_token = { type = TOKEN_QUOTED, content = "" }
				elif c == "#":
					break
				else:
					state = TokenizerState.ReadingToken
					current_token = { type = TOKEN_RAW, content = c }
					
			TokenizerState.ReadingToken:
				if c == " ":
					tokens.append(current_token)
					current_token = {} # actually unnecessary
					state = TokenizerState.WaitingNextToken
				elif c == "\"":
					compiled_script.add_error("Unexpected quote inside token (line %s)" % line_number)
					return []
				elif c == "#":
					compiled_script.add_error("Unexpected '#' inside token (line %s)" % line_number)
					return []
				else:
					current_token.content += c
			
			TokenizerState.ReadingQuotedToken:
				if c == "\"":
					tokens.append(current_token)
					current_token = {} # actually unnecessary
					state = TokenizerState.WaitingSpace
				elif c == "\\":
					state = TokenizerState.ReadingEscapeSequence
				else:
					current_token.content += c
			
			TokenizerState.ReadingEscapeSequence:
				if not c in ["\\", "\""]:
					compiled_script.add_error("Invalid escape sequence (line %s)" % line_number)
					return []
				
				current_token.content += c # escaped character in quote
				state = TokenizerState.ReadingQuotedToken
				
			TokenizerState.WaitingSpace:
				if c == " ":
					state = TokenizerState.WaitingNextToken
				elif c == "#":
					break
				else:
					compiled_script.add_error("Unexpected char '%s' after closing quote (line %s)" % [c, line_number])
					return []
			_:
				push_error("Unexpected state %s" % state)
				return []
		
	match state:
		TokenizerState.ReadingToken:
			tokens.append(current_token)
			current_token = {} # actually unnecessary
		TokenizerState.ReadingQuotedToken, TokenizerState.ReadingEscapeSequence:
			compiled_script.add_error("Unexpected end of line while reading quoted token (line %s)" % line_number)
			return []
		
	return tokens

#####################

func float_str_is_valid(float_str: String) -> bool:
	return contains_regex(float_str, float_regex())

func token_str(token: Dictionary) -> String:
	match token.type:
		TOKEN_RAW:
			return token.content
		TOKEN_QUOTED:
			return "\"\"\"%s\"\"\"" % token.content
		_:
			push_error("Unexpected type %s" % token.type)
			return token.content

func number_of_leading_tabs(raw_line: String) -> int:
	var ret = 0
	
	for i in range(raw_line.length()):
		var c = raw_line[i]
		
		if c == "\t":
			ret += 1
		else:
			break
		
	return ret

#####################

func contains_pattern(a_string: String, pattern_str: String) -> bool:
	var regex = build_regex(pattern_str)
	return contains_regex(a_string, regex)

func contains_regex(a_string: String, regex: RegEx) -> bool:
	var result = regex.search(a_string)
	
	return result != null

func sequence_header_regex():
	return build_regex(sequence_header_regex_pattern)

func command_regex():
	return build_regex(command_regex_pattern)

func float_regex():
	return build_regex(float_regex_pattern)

func build_regex(pattern):
	var ret = RegEx.new()
	ret.compile(pattern)
	return ret
