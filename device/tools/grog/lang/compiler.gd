extends Node

const float_regex_pattern = "^([0-9]+|[0-9]*\\.[0-9]+)$"
var float_regex: RegEx

const command_regex_pattern = "^[a-z\\_]+$"
var command_regex: RegEx

const identifier_regex_pattern = "^(\\$*)([a-zA-Z0-9\\_]+(\\/[a-zA-Z0-9\\_]+)*)$"
var identifier_regex: RegEx

const pattern_regex_pattern = "^[a-zA-Z0-9\\_\\/\\*]+$"
var pattern_regex: RegEx

const number_characters = "0123456789"
const operator_characters = "<>=:()+-"

const standard_token_character_pattern = "[a-zA-Z0-9\\_\\/\\$\\.\\*]"
var standard_token_character_regex: RegEx

enum TokenizerState {
	WaitingNextToken,
	
	# any string formed by numbers, letters, underscores, dots, slashes and $
	# if it starts with a number digit it is read as number
	# else it's read as standard token and can represent
	#     - a keyword (if, else, not, false)
	#     - an identifier (room1/item, $variable, $$option)
	#     - a command (room1/item.disable, .add, .load_room, $$object.enable)
	ReadingStandardTokenOrNumber,
	
	ReadingQuote,
	ReadingEscapeSequence
}

func _ready():
	float_regex = build_regex(float_regex_pattern)
	command_regex = build_regex(command_regex_pattern)
	identifier_regex = build_regex(identifier_regex_pattern)
	standard_token_character_regex = build_regex(standard_token_character_pattern)
	pattern_regex = build_regex(pattern_regex_pattern)

func compile_text(code: String) -> CompiledGrogScript:
	var compiled_script = CompiledGrogScript.new()
	
	if code.find("\r") != -1:
		print("Warning: unexpected carriage returns in code")
		print("removing them...")
		
		code = code.replace("\r", "")
	
	var raw_lines: Array = code.split("\n")
	
	var lines = []
	
	for i in range(raw_lines.size()):
		var line_data = { raw = raw_lines[i], line_number = i + 1 }
		
		tokenize_line(compiled_script, line_data) # sets 'blank', 'indent_level' and 'tokens' in line_data
		
		if not compiled_script.is_valid:
			return compiled_script
		
		if not line_data.blank:
			lines.append(line_data)
	
	compile_lines(compiled_script, lines)
	
	return compiled_script

func tokenize_line(compiled_script, line: Dictionary) -> void: 
	line.indent_level = number_of_leading_tabs(line.raw)
	line.raw_content = line.raw.substr(line.indent_level)
	
	if line.raw_content.length() == 0:
		line.blank = true
	#elif line.raw_content.find("\t") != -1:
	#	compiled_script.add_error("(%s:%s) tabs can only be at the start of the line" % [line.line_number, line.indent_level + line.raw_content.find("\t") + 1])
	#	return
	elif line.raw_content.begins_with(" "):
		compiled_script.add_error("(%s:%s) line can't start with spaces" % [line.line_number, line.indent_level + 1])
		return
	else:
		line.tokens = get_tokens(compiled_script, line)
		
		if not compiled_script.is_valid:
			# Invalid line
			return
			
		line.blank = line.tokens.size() == 0

# Tokenizing

func get_tokens(compiled_script, line: Dictionary) -> Array:
	var tokens = []
	
	var current_token: Dictionary
	var state = TokenizerState.WaitingNextToken
	
	var char_number = line.indent_level
	
	for i in range(line.raw_content.length()):
		char_number += 1
		var c = line.raw_content[i]
		
		match state:
			TokenizerState.WaitingNextToken:
				if c == " ": # token separation
					pass
				elif c == "\"": # quote start
					state = TokenizerState.ReadingQuote
					current_token = { type = Grog.TokenType.Quote, content = "" }
				elif c == "#": # comment start
					line.comment = line.raw_content.substr(i + 1).strip_edges()
					break
				elif c in operator_characters: # operator
					tokens.append({ type = Grog.TokenType.Operator, content = c })
				elif c in number_characters: # number
					state = TokenizerState.ReadingStandardTokenOrNumber
					current_token = { type = Grog.TokenType.Number, content = c }
				elif contains_pattern(c, standard_token_character_regex): # start of standard token
					state = TokenizerState.ReadingStandardTokenOrNumber
					current_token = { type = Grog.TokenType.Standard, content = c }
				else:
					if c == "\t":
						compiled_script.add_error("(%s:%s) invalid tab" % [line.line_number, char_number])
						compiled_script.add_error("you may have erroneous spaces or characters mixed with tabs")
					else:
						compiled_script.add_error("(%s:%s) invalid char '%s'" % [line.line_number, char_number, c])
					return []
			
			TokenizerState.ReadingStandardTokenOrNumber:
				if c == " ": # end of this token
					var token = recognize_token(current_token.content, current_token.type == Grog.TokenType.Number)
					
					if not token.valid:
						compiled_script.add_error("(%s:%s) invalid token '%s': %s" % [line.line_number, char_number - current_token.content.length(), current_token.content, token.msg])
						return []
					
					current_token.type = token.type
					current_token.data = token.data
					
					tokens.append(current_token)
					
					current_token = {} # actually unnecessary
					state = TokenizerState.WaitingNextToken
				elif c == "\"":
					compiled_script.add_error("(%s:%s) unexpected quote inside token" % [line.line_number, char_number])
					return []
				elif c == "#":
					compiled_script.add_error("(%s:%s) unexpected hash symbol inside token" % [line.line_number, char_number])
					return []
				elif c in operator_characters: # operator after current token
					var token = recognize_token(current_token.content, current_token.type == Grog.TokenType.Number)
					
					if not token.valid:
						compiled_script.add_error("(%s:%s) invalid token '%s': %s" % [line.line_number, char_number - current_token.content.length(), current_token.content, token.msg])
						return []
					
					current_token.type = token.type
					current_token.data = token.data
					
					tokens.append(current_token)
					
					current_token = {} # actually unnecessary
					tokens.append({ type = Grog.TokenType.Operator, content = c })
					state = TokenizerState.WaitingNextToken
				elif contains_pattern(c, standard_token_character_regex): # token continued
					current_token.content += c
				else:
					if c == "\t":
						compiled_script.add_error("(%s:%s) invalid tab" % [line.line_number, char_number])
					else:
						compiled_script.add_error("(%s:%s) invalid char in token '%s'" % [line.line_number, char_number, c])
					return []
					
			TokenizerState.ReadingQuote:
				if c == "\"": # quote end
					tokens.append(current_token)
					current_token = {} # actually unnecessary
					state = TokenizerState.WaitingNextToken
				elif c == "\\": # escape sequence start
					state = TokenizerState.ReadingEscapeSequence
				elif c == "\t": # erroneous tab inside quote
					compiled_script.add_error("(%s:%s) invalid tab inside quote" % [line.line_number, char_number])
					return []
				else: # quote continued
					current_token.content += c
			
			TokenizerState.ReadingEscapeSequence:
				if not c in ["\\", "\""]: # escape sequence end
					compiled_script.add_error("(%s:%s) invalid escape sequence" % [line.line_number, char_number])
					return []
				
				current_token.content += c # escaped character in quote
				state = TokenizerState.ReadingQuotedToken
			
			_:
				compiled_script.add_error("Grog error: unexpected state %s" % TokenizerState.keys()[state])
				return compiled_script
	
	match state:
		TokenizerState.ReadingQuote:
			compiled_script.add_error("(%s:%s) unexpected end of line reading quote" % [line.line_number, char_number])
			return []
		
		TokenizerState.ReadingEscapeSequence:
			compiled_script.add_error("(%s:%s) unexpected end of line reading escape sequence" % [line.line_number, char_number])
			return []
		
		TokenizerState.ReadingStandardTokenOrNumber:
			var token = recognize_token(current_token.content, current_token.type == Grog.TokenType.Number)
			
			if not token.valid:
				compiled_script.add_error("(%s:%s) invalid token '%s': %s" % [line.line_number, char_number - current_token.content.length(), current_token.content, token.msg])
				return []
			
			current_token.type = token.type
			current_token.data = token.data
			
			tokens.append(current_token)
			
	return tokens

func recognize_token(content: String, parse_as_number: bool) -> Dictionary:
	if parse_as_number:
		if not is_valid_number_str(content):
			return { valid = false, msg = "invalid number" }
		elif content.find(".") != -1:
			return { valid = true, type = Grog.TokenType.Float, data = { number_value = float(content) } }
		else:
			return { valid = true, type = Grog.TokenType.Integer, data = { number_value = int(content) } }
	else:
		var dot_location = content.find(".")
		var is_command = dot_location != -1
		
		var ret = { valid = true, content = content, data = { } }
		
		if is_command:
			var subject = content.substr(0, dot_location)
			var command_name = content.substr(dot_location + 1)
			
			if Grog.keywords.has(subject):
				return { valid = false, msg = "keyword used as subject" }
			
			if not contains_pattern(command_name, command_regex):
				return { valid = false, msg = "invalid command" }
			elif not Grog.commands.has(command_name):
				return { valid = false, msg = "command not found" }
			
			ret.type = Grog.TokenType.Command
			ret.data.command_name = command_name
			
			var indirection_level = 0
			var key = ""
			
			if subject != "":
				var result = identifier_regex.search(subject)
				if not result:
					return { valid = false, msg = "invalid subject" }
				
				indirection_level = result.strings[1].length()
				if indirection_level > 0:
					return { valid = false, msg = "can't have $indirection in command" }
				
				key = result.strings[2]
				
			ret.data.subject = subject
			ret.data.indirection_level = indirection_level
			ret.data.key = key
		
		elif Grog.keywords.has(content):
			ret.type = Grog.keywords[content]
		else:
			var result = identifier_regex.search(content)
			
			if result:
				ret.type = Grog.TokenType.Identifier
				ret.data.indirection_level = result.strings[1].length()
				ret.data.key = result.strings[2]
				
			elif pattern_regex.search(content):
				ret.type = Grog.TokenType.Pattern
			else:
				return { valid = false, msg = "invalid identifier or pattern" }
		
		return ret
	
# Compiling

func compile_lines(compiled_script, lines: Array):
	var num_lines = lines.size()
	
	var statements = []
	var stack = []
	var level = 0
	var i = 0
	var line
	
	while true:
		var more_lines = i < num_lines
		
		var new_level
		
		if more_lines:
			line = lines[i]
			i += 1
			new_level = line.indent_level
			if new_level > level:
				compiled_script.add_error("Invalid indentation (line %s)" % line.line_number)
				return
		else:
			new_level = 0
		
		assert(level == stack.size())
		
		if new_level < level:
			var diff_level = level - new_level
			
			for _j in range(diff_level):
				level -= 1
				var previous_level = stack.pop_back()
				
				var current_block = previous_level.back()
				
				if current_block.type == "sequence":
					assert(stack.size() == 0)
					assert(level == 0)
				
					current_block.instructions = statements
					
				elif current_block.type == "if":
					assert(stack.size() > 0)
					assert(stack.size() == level)
					
					if current_block.has("condition"):
						if not current_block.has("main_branches"):
							current_block.main_branches = []
						
						current_block.main_branches.append({
							condition = current_block.condition,
							statements = statements
						})
					else:
						assert(not current_block.has("else_branch"))
						current_block.else_branch = statements
				elif current_block.type == "loop":
					assert(stack.size() > 0)
					assert(stack.size() == level)
					
					assert(not current_block.has("statements"))
					current_block.statements = statements
					
				else:
					compiled_script.add_error("Grog error: unexpected line type '%s'" % current_block.type)
					return
					
				statements = previous_level
				
		assert(level == new_level)
		assert(level == stack.size())
		
		if not more_lines:
			break
		
		var first_token = line.tokens[0]
		var k = 1
		var num_tokens = line.tokens.size()
		
		if level == 0: # sequence header
			assert(stack.size() == 0)
			assert(level == 0)
			
			if not _token_is_straight_identifier(first_token):
				compiled_script.add_error("Invalid trigger name (line %s)" % line.line_number)
				return
			
			if num_tokens <= k:
				compiled_script.add_error("Missing colon after trigger name (line %s)" % line.line_number)
				return
			
			var colon_token = line.tokens[k]
			k += 1
			
			if not _token_is_operator(colon_token, ":") and not _token_is_operator(colon_token, "("):
				compiled_script.add_error("Expecting : or ( after trigger name (line %s)" % line.line_number)
				return
			
			var pattern = null
			
			if colon_token.content == "(":
				# header with parameter
				
				if num_tokens <= k:
					compiled_script.add_error("Missing pattern after opening parentheses (line %s)" % line.line_number)
					return
				var pattern_token = line.tokens[k]
				k += 1
				
				if pattern_token.type == Grog.TokenType.Pattern:
					pattern = pattern_token.content
				elif pattern_token.type == Grog.TokenType.Identifier:
					if pattern_token.data.indirection_level > 0:
						compiled_script.add_error("Pattern can't have $indirection (line %s)" % line.line_number)
						return
					
					pattern = pattern_token.content
				
				if num_tokens <= k:
					compiled_script.add_error("Missing ) after header pattern (line %s)" % line.line_number)
					return
				
				var closing_parentheses = line.tokens[k]
				k += 1
				
				if not _token_is_operator(closing_parentheses, ")"):
					compiled_script.add_error("Expecting ) after pattern (line %s)" % line.line_number)
					return
				
				if num_tokens <= k:
					compiled_script.add_error("Missing colon after closing pharentheses (line %s)" % line.line_number)
					return
				
				colon_token = line.tokens[k]
				k += 1
				
				if not _token_is_operator(colon_token, ":"):
					compiled_script.add_error("Expecting : or after closing pharentheses (line %s)" % line.line_number)
					return
			
			var is_telekinetic = false
			while num_tokens > k:
				var option_token = line.tokens[k]
				k += 1
				
				if _token_is_straight_identifier(option_token) or option_token.to_lower() == "tk":
					is_telekinetic = true
				else:
					compiled_script.add_error("Invalid sequence parameter (only TK allowed) (line %s)" % line.line_number)
					return
			
			statements.append({
				type = "sequence",
				trigger_name = first_token.data.key,
				telekinetic = is_telekinetic,
				pattern = pattern
				# waiting for instructions
			})
			
			stack.push_back(statements)
			statements = []
			level += 1
		
		else: # instruction (command or if/else opening)
			match first_token.type:
				Grog.TokenType.Command:
					if first_token.data.indirection_level > 0:
						compiled_script.add_error("Indirection levels not implemented yet (line %s)" % line.line_number)
						return
					
					var subject = first_token.data.key
					var command_name = first_token.data.command_name
					
					assert(Grog.commands.has(command_name))
					
					var command_requirements = Grog.commands[command_name]
					var has_named_params = command_requirements.has("named_params")
					
					match command_requirements.subject:
						Grog.SubjectType.None:
							if subject:
								compiled_script.add_error("Command '%s' can't have subject (line %s)" % [command_name, line.line_number])
								return
						Grog.SubjectType.Required:
							if not subject:
								compiled_script.add_error("Command '%s' must have a subject (line %s)" % [command_name, line.line_number])
								return
						Grog.SubjectType.Optional:
							pass
						_:
							compiled_script.add_error("Grog error: unexpected subject type %s" % Grog.SubjectType.keys()[command_requirements.subject])
							return
					
					var final_params = []
					
					if command_requirements.subject != Grog.SubjectType.None:
						final_params.append(subject)
					
					var total_params = num_tokens - 1
					var required = command_requirements.required_params
					var num_required = required.size()
					
					for j in range(num_required):
						var param = required[j]
						if total_params < j + 1:
							compiled_script.add_error("Parameter '%s' expected (line %s)" % [param.name, line.line_number])
							return
						
						var actual_param = line.tokens[j + 1]
						
						#var ignore_param = false
						#var param_value
						
						match param.type:
							Grog.ParameterType.BooleanType:
								if actual_param.type == Grog.TokenType.TrueKeyword:
									final_params.append(true)
								elif actual_param.type == Grog.TokenType.FalseKeyword:
									final_params.append(false)
								else:
									compiled_script.add_error("Parameter '%s' must be true or false (line %s)" % [param.name, line.line_number])
									return
							
							Grog.ParameterType.FloatType:
								if actual_param.type != Grog.TokenType.Float and actual_param.type != Grog.TokenType.Integer:
									compiled_script.add_error("Parameter '%s' must be a float or int (line %s)" % [param.name, line.line_number])
									return
								
								final_params.append(actual_param.data.number_value)
							
							Grog.ParameterType.EqualsSign:
								if actual_param.type != Grog.TokenType.Operator or actual_param.content != "=":
									compiled_script.add_error("Expected equals sign in command %s (line %s)" % [command_name, line.line_number])
									return
								
							Grog.ParameterType.Fixed:
								if actual_param.type != Grog.TokenType.Identifier or actual_param.data.indirection_level != 0 or actual_param.data.key != param.name:
									compiled_script.add_error("Expected '%s' in command %s (line %s)" % [param.name, command_name, line.line_number])
									return
								
							Grog.ParameterType.Identifier:
								if actual_param.type != Grog.TokenType.Identifier:
									compiled_script.add_error("Expected identifier in command %s (line %s)" % [command_name, line.line_number])
									return
									
								if actual_param.data.indirection_level != 0:
									compiled_script.add_error("Indirection levels not implemented in command %s (line %s)" % [command_name, line.line_number])
									return
								
								final_params.append(actual_param.data.key)
							
							Grog.ParameterType.QuoteOrIdentifier:
								if actual_param.type != Grog.TokenType.Identifier and actual_param.type != Grog.TokenType.Quote:
									compiled_script.add_error("Expected identifier or quote in command %s (line %s)" % [command_name, line.line_number])
									return
								
								if actual_param.type == Grog.TokenType.Identifier:
									actual_param.expression = IdentifierExpression.new(actual_param.data.indirection_level, actual_param.data.key)
								else:
									actual_param.expression = FixedExpression.new(actual_param.content)
									
								final_params.append(actual_param)
							
							Grog.ParameterType.ExpressionType:
								if j != num_required - 1:
									compiled_script.add_error("Grog error; expression must be last parameter (line %s)" % [line.line_number])
									return
								elif has_named_params:
									compiled_script.add_error("Grog error; expression can't have options (line %s)" % [line.line_number])
									return
								
								var expression_tokens = line.tokens.slice(j + 1, line.tokens.size() - 1)
								var expression = parse_expression(expression_tokens)
					
								if not expression.result:
									compiled_script.add_error("Invalid expression (%s) (line %s)" % [expression.message, line.line_number])
									return 
								
								final_params.append(expression.result)
								
							_:
								compiled_script.add_error("Grog error: unexpected parameter type %s" % Grog.ParameterType.keys()[param.type])
								return
						
					# end for
					
					if not has_named_params:
						if total_params > num_required and (num_required == 0 or required[num_required - 1].type != Grog.ParameterType.ExpressionType):
							compiled_script.add_error("Command '%s' requires only %s parameters (line %s)" % [command_name, num_required, line.line_number])
							return
					else:
						var options = {}
						
						var j = num_required + 1
						
						while true:
							if num_tokens <= j:
								break
							
							var extra_token = line.tokens[j]
							
							if extra_token.type != Grog.TokenType.Identifier or extra_token.data.indirection_level != 0:
								compiled_script.add_error("Expecting option name (line %s)" % line.line_number)
								return
							
							var option_name = extra_token.data.key
							
							var np = get_named_param(command_requirements.named_params, option_name)
							
							if np == null:
								compiled_script.add_error("Invalid option '%s' in command %s (line %s)" % [option_name, command_name, line.line_number])
								return
							
							if options.has(option_name):
								compiled_script.add_error("Duplicated option '%s' in command %s (line %s)" % [option_name, command_name, line.line_number])
								return
							
							if num_tokens <= j + 1 or line.tokens[j + 1].type != Grog.TokenType.Operator or line.tokens[j + 1].content != "=":
								compiled_script.add_error("Expecting equals sign after option '%s' in command %s (line %s)" % [option_name, command_name, line.line_number])
								return
							
							if num_tokens <= j + 2:
								compiled_script.add_error("Expecting value for option '%s' in command %s (line %s)" % [option_name, command_name, line.line_number])
								return
							
							var value_token = line.tokens[j + 2]
							
							var option_value
							
							match np.type:
								Grog.ParameterType.BooleanType:
									if value_token.type == Grog.TokenType.TrueKeyword:
										option_value = true
									elif value_token.type == Grog.TokenType.FalseKeyword:
										option_value = false
									else:
										compiled_script.add_error("Option '%s' must be true or false in command %s (line %s)" % [option_name, command_name, line.line_number])
										return
								
								Grog.ParameterType.FloatType:
									if value_token.type != Grog.TokenType.Float and value_token.type != Grog.TokenType.Integer:
										compiled_script.add_error("Option '%s' must be a number in command %s (line %s)" % [option_name, command_name, line.line_number])
										return
									
									option_value = value_token.data.number_value
								
								_:
									compiled_script.add_error("Grog error: unexpected option type %s" % Grog.ParameterType.keys()[np.type])
									return
							
							options[option_name] = option_value
							j += 3
						# end while
						
						final_params.append(options)
					# end if
					
					statements.append({
						type = "command",
						command = command_name,
						params = final_params
					})
				
				Grog.TokenType.IfKeyword:
					if num_tokens < 2:
						compiled_script.add_error("If condition expected (line %s)" % line.line_number)
						return
					
					var last_token = line.tokens[num_tokens - 1]
					if last_token.type != Grog.TokenType.Operator or last_token.content != ":":
						compiled_script.add_error("Colon expected at end of 'if' line (line %s)" % line.line_number)
						return
					
					if num_tokens < 3:
						compiled_script.add_error("Missing if condition (line %s)" % line.line_number)
						return
					
					var condition_tokens = line.tokens.slice(1, num_tokens - 2)
					
					var condition = parse_expression(condition_tokens)
					
					if not condition.result:
						compiled_script.add_error("Invalid if condition (%s) (line %s)" % [condition.message, line.line_number])
						return
					
					statements.append({
						type = "if",
						condition = condition.result,
						# waiting for condition_branches/else_branch
					})
					
					stack.push_back(statements)
					statements = []
					level += 1
				
				Grog.TokenType.ElifKeyword:
					if statements.size() == 0:
						compiled_script.add_error("Unexpected 'elif' block (line %s)" % line.line_number)
						return
					
					var previous_statement = statements.back()
					if previous_statement.type != "if" or previous_statement.has("else_branch"):
						compiled_script.add_error("Unexpected 'elif' block (line %s)" % line.line_number)
						return
					
					if num_tokens < 2:
						compiled_script.add_error("Elif condition expected (line %s)" % line.line_number)
						return
					
					var last_token = line.tokens[num_tokens - 1]
					if last_token.type != Grog.TokenType.Operator or last_token.content != ":":
						compiled_script.add_error("Colon expected at end of 'elif' line (line %s)" % line.line_number)
						return
					
					if num_tokens < 3:
						compiled_script.add_error("Missing elif condition (line %s)" % line.line_number)
						return
					
					var condition_tokens = line.tokens.slice(1, num_tokens - 2)
					
					var condition = parse_expression(condition_tokens)
					
					if not condition.result:
						compiled_script.add_error("Invalid elif condition (%s) (line %s)" % [condition.message, line.line_number])
						return
					
					previous_statement.condition = condition.result
					
					stack.push_back(statements)
					statements = []
					level += 1
					
				Grog.TokenType.ElseKeyword:
					if statements.size() == 0:
						compiled_script.add_error("Unexpected 'else' block (line %s)" % line.line_number)
						return
					
					var previous_statement: Dictionary = statements.back()
					if previous_statement.type != "if" or previous_statement.has("else_branch"):
						compiled_script.add_error("Unexpected 'else' block (line %s)" % line.line_number)
						return
					
					var _r = previous_statement.erase("condition")
					assert(_r)
					
					if num_tokens < 2:
						compiled_script.add_error("Colon expected after 'else' (line %s)" % line.line_number)
						return
					
					var second_token = line.tokens[1]
					if second_token.type != Grog.TokenType.Operator or second_token.content != ":":
						compiled_script.add_error("Colon expected after 'else' (line %s)" % line.line_number)
						return
					
					if num_tokens > 2:
						compiled_script.add_error("End of line expected after 'else:' (line %s)" % line.line_number)
						return
					
					stack.push_back(statements)
					statements = []
					level += 1
				
				Grog.TokenType.LoopKeyword:
					if num_tokens < 2:
						compiled_script.add_error("Colon expected after 'loop' (line %s)" % line.line_number)
						return
					
					var colon_token = line.tokens[1]
					if not _token_is_operator(colon_token, ":"):
						compiled_script.add_error("Expecting : after 'loop' (line %s)" % line.line_number)
						return
					
					if num_tokens > 2:
						compiled_script.add_error("End of line expected after 'loop:' (line %s)" % line.line_number)
						return
					
					statements.append({
						type = "loop",
						# waiting for statements
					})
					
					stack.push_back(statements)
					statements = []
					level += 1
				
				Grog.TokenType.BreakKeyword:
					if num_tokens > 1:
						compiled_script.add_error("End of line expected after 'break' (line %s)" % line.line_number)
						return
					
					statements.append({
						type = "break"
					})
					
				_:
					compiled_script.add_error("Command, if or else expected at start of line (line %s)" % line.line_number)
					return
					
			# end match first_token.type
			
		# end if (sequence header versus instruction line)
		
	# end while true
	
	assert(stack.size() == 0)
	assert(level == 0)
	
	for seq in statements:
		if seq.pattern:
			compiled_script.add_sequence_with_parameter(seq.trigger_name, seq.pattern, {
				statements = seq.instructions,
				telekinetic = seq.telekinetic,
			})
		else:
			compiled_script.add_sequence(seq.trigger_name, {
				statements = seq.instructions,
				telekinetic = seq.telekinetic
			})

func get_named_param(named_params: Array, name: String):
	for np in named_params:
		if np.name == name:
			return np
	
	return null

func parse_expression(tokens: Array) -> Dictionary:
	var p = Parser.new()
	var r
	
	for token in tokens:
		match token.type:
			Grog.TokenType.Command, Grog.TokenType.Pattern:
				return { result = false, message = "invalid token '%s'" % token.content}
			
			Grog.TokenType.Identifier:
				r = p.read_token(token, 100, false, false)
				if not r.result:
					return r
				
			Grog.TokenType.Integer, Grog.TokenType.Float, Grog.TokenType.FalseKeyword, Grog.TokenType.TrueKeyword, Grog.TokenType.Quote:
				r = p.read_token(token, 100, false, false)
				if not r.result:
					return r
				
			Grog.TokenType.Operator, Grog.TokenType.AndKeyword,  Grog.TokenType.OrKeyword, Grog.TokenType.NotKeyword:
				if token.content == "(":
					r = p.open_parenthesis()
					if not r.result:
						return r
				elif token.content == ")":
					r = p.close_parenthesis()
					if not r.result:
						return r
				elif not Grog.parser_operators.has(token.content):
					return { result = false, message = "invalid operator '%s'" % token.content}
				else:
					r = p.read_token(token, Grog.parser_operators[token.content].precedence, token.type != Grog.TokenType.NotKeyword, true)
					if not r.result:
						return r
			
			_:
				return { result = false, message = "invalid token '%s'" % token.content}
	
	r = p.finish()
	if not r.result:
		return r
	
	
	var root = r.root
	
	assert(root.has("right"))
	assert(not root.has("left"))
	
	var ret = node_to_expression(root.right)
	
	if not ret.result:
		return ret
	
	return ret

func node_to_expression(node):
	if not node.token.has("type"):
		print("Caso muy raro")
		print(node.token)
		return { result = false, message = "rarisimo"}
	
	match node.token.type:
		Grog.TokenType.Integer, Grog.TokenType.Float:
			assert(not node.has("left"))
			assert(not node.has("right"))
			return { result = FixedExpression.new(node.token.data.number_value) }
		Grog.TokenType.TrueKeyword:
			assert(not node.has("left"))
			assert(not node.has("right"))
			return { result = FixedExpression.new(true) }
		Grog.TokenType.FalseKeyword:
			assert(not node.has("left"))
			assert(not node.has("right"))
			return { result = FixedExpression.new(false) }
		Grog.TokenType.Quote:
			assert(not node.has("left"))
			assert(not node.has("right"))
			return { result = FixedExpression.new(node.token.content) }
		Grog.TokenType.Identifier:
			assert(not node.has("left"))
			assert(not node.has("right"))
			return { result = IdentifierExpression.new(node.token.data.indirection_level, node.token.data.key) }
		
		Grog.TokenType.NotKeyword:
			assert(not node.has("left"))
			assert(node.has("right"))
			
			var right = node_to_expression(node.right)
			if not right.result:
				return right
			return { result = NegatedBoolExpression.new(right.result) }
			
		Grog.TokenType.AndKeyword, Grog.TokenType.OrKeyword, Grog.TokenType.Operator:
			if not node.has("right"):
				return { result = false, message = "missing second parameter for binary operator %s" % node.token.content }
			
			if not node.has("left"):
				if node.token.content == "-":
					# unary - operator
					var right = node_to_expression(node.right)
					if not right.result:
						return right
					return { result = InverseNumberExpression.new(right.result) }
				
				return { result = false, message = "1unexpected binary operator %s" % node.token.content }
			
			var left = node_to_expression(node.left)
			if not left.result:
				return left
			
			var right = node_to_expression(node.right)
			if not right.result:
				return right
			
			return { result = OperationExpression.new(left.result, node.token.content, right.result) }
		_:
			return { result = false, message = "unexpected node %s" % Grog.TokenType.keys()[node.token.type] }
	pass

# Misc

func number_of_leading_tabs(raw_line: String) -> int:
	var ret = 0
	
	for i in range(raw_line.length()):
		var c = raw_line[i]
		
		if c == "\t":
			ret += 1
		else:
			break
		
	return ret

func build_regex(pattern: String) -> RegEx:
	var ret = RegEx.new()
	ret.compile(pattern)
	return ret

func contains_pattern(a_string: String, pattern: RegEx) -> bool:
	var result = pattern.search(a_string)
	return result != null

func is_valid_number_str(a_string: String) -> bool:
	return contains_pattern(a_string, float_regex)

###

func _token_is_straight_identifier(token):
	return token.type == Grog.TokenType.Identifier and token.data.indirection_level == 0

func _token_is_operator(token, operator: String):
	return token.type == Grog.TokenType.Operator or token.content == operator