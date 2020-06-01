class_name Grog

enum SubjectType {
	None,
	Required,
	Optional
}

enum ParameterType {
	Identifier,
	EqualsSign,
	BooleanType,
	FloatType,
	QuoteOrIdentifier,
	Fixed,
	ExpressionType
}

enum TokenType {
	Standard, Command, Identifier, Pattern, # or Keyword (next lines)
	IfKeyword, ElifKeyword, ElseKeyword,
	LoopKeyword, BreakKeyword,
	NotKeyword, AndKeyword, OrKeyword, TrueKeyword, FalseKeyword,
	
	Number, Integer, Float,
	Quote,
	Operator
}

const parser_operators = {
	"+": { precedence = 20 },
	"-": { precedence = 20 },
	"=": { precedence = 18 },
	"<": { precedence = 18 },
	">": { precedence = 18 },
	"not": { precedence = 16 },
	"and": { precedence = 14 },
	"or": { precedence = 12 },
	#"*": { precedence = 2 },
	#"/": { precedence = 2 },
}

const keywords = {
	"if": TokenType.IfKeyword,
	"elif": TokenType.ElifKeyword,
	"else": TokenType.ElseKeyword,
	"loop": TokenType.LoopKeyword,
	"break": TokenType.BreakKeyword,
	"not": TokenType.NotKeyword,
	"and": TokenType.AndKeyword,
	"or": TokenType.OrKeyword,
	"true": TokenType.TrueKeyword,
	"false": TokenType.FalseKeyword,
}

const commands = {
	load_room = {
		subject = SubjectType.None,
		required_params = [
			{ name = "room_name", type = ParameterType.Identifier }
		],
		named_params = [
			{ name = "at", type = ParameterType.Identifier }
		]
	},
	wait = {
		subject = SubjectType.None,
		required_params = [
			{ name = "duration", type = ParameterType.FloatType }
		],
		named_params = [
			{ name = "skippable", type = ParameterType.BooleanType }
		]
	},
	say = {
		subject = SubjectType.Optional,
		required_params = [
			{ name = "speech", type = ParameterType.QuoteOrIdentifier }
		],
		named_params = [
			{ name = "duration", type = ParameterType.FloatType },
			{ name = "skippable", type = ParameterType.BooleanType }
		]
	},
	walk = {
		subject = SubjectType.Required,
		required_params = [
			{ name = "to", type = ParameterType.Fixed },
			{ name = "equals", type = ParameterType.EqualsSign },
			{ name = "value", type = ParameterType.Identifier }
		]
	},
	
	# end the game
	end = {
		subject = SubjectType.None,
		required_params = []
	},
	
	# set value to global variable
	# (currently only bool values, they are false by default)
	set = {
		subject = SubjectType.None,
		required_params = [
			{ name = "variable_name", type = ParameterType.Identifier },
			{ name = "equals", type = ParameterType.EqualsSign },
			{ name = "value", type = ParameterType.ExpressionType }
		]
	},
	
	# enable/disable item
	# (they are active by default and can be disabled to hide them and prevent interaction)
	enable = {
		subject = SubjectType.Required,
		required_params = []
	},
	disable = {
		subject = SubjectType.Required,
		required_params = []
	},
	
	# add/remove inventory item
	add = {
		subject = SubjectType.Required,
		required_params = []
	},
	remove = {
		subject = SubjectType.Required,
		required_params = []
	},
	
	# play animation
	play = {
		subject = SubjectType.Required,
		required_params = [
			{ name = "animation_name", type = ParameterType.Identifier }
		]
	},
	
	# set item as 'tool'
	set_tool = {
		subject = SubjectType.Required,
		required_params = [
			{ name = "tool_verb", type = ParameterType.Identifier }
		]
	},
	
	debug = {
		subject = SubjectType.None,
		required_params = [
			{ name = "value", type = ParameterType.ExpressionType }
		]
	},
	
	teleport = {
		subject = SubjectType.Required,
		required_params = [
			{ name = "to", type = ParameterType.Fixed },
			{ name = "equals", type = ParameterType.EqualsSign },
			{ name = "value", type = ParameterType.Identifier }
		],
		named_params = [
			{ name = "angle", type = ParameterType.FloatType }
		]
	},
	
	curtain_up = {
		subject = SubjectType.None,
		required_params = []
	},
	curtain_down = {
		subject = SubjectType.None,
		required_params = []
	},
	
}

const item_id_separator := "/"

static func get_item_id(item_key: String, instance_number: int) -> String:
	return "%s%s%s" % [item_key, item_id_separator, instance_number]

static func get_item_key_and_number(item_id: String) -> Dictionary:
	var index: int = item_id.find_last(item_id_separator)
	
	var separator_length: int = item_id_separator.length()
	
	var instance_number_index: int = index + separator_length
	
	if index < 0 or item_id.length() <= instance_number_index:
		return { valid = false }
	return {
		valid = true,
		item_key = item_id.substr(0, index),
		instance_number = int(item_id.substr(instance_number_index))
	}

static func _typestr(value):
	match typeof(value):
		TYPE_ARRAY:
			return "Array"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_DICTIONARY:
			return "Dictionary"
		TYPE_OBJECT:
			return "Object"
		TYPE_NIL:
			return "null"
		TYPE_STRING:
			return "String"
		_:
			return "another:%s" % typeof(value)
