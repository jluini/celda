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
	Standard, Command, Identifier, Pattern, # or Keyword (next line)
	IfKeyword, ElifKeyword, ElseKeyword, NotKeyword, AndKeyword, OrKeyword, TrueKeyword, FalseKeyword,
	
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
		]
	},
	enable_input = {
		subject = SubjectType.None,
		required_params = []
	},
	disable_input = {
		subject = SubjectType.None,
		required_params = []
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
			{ name = "animation_name", type = ParameterType.QuoteOrIdentifier }
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
			
