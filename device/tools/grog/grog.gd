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
	Fixed
}

enum TokenType {
	Standard, Command, Identifier, # or Keyword (next line)
	IfKeyword, ElseKeyword, NotKeyword, AndKeyword, OrKeyword, TrueKeyword, FalseKeyword,
	
	Number, Integer, Float,
	Quote,
	Operator
}

const keywords = {
	"if": TokenType.IfKeyword,
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
			{ name = "value", type = ParameterType.BooleanType }
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
		subject = SubjectType.None,
		required_params = [
			{ name = "item_id", type = ParameterType.Identifier }
		]
	},
	remove = {
		subject = SubjectType.None,
		required_params = [
			{ name = "item_id", type = ParameterType.Identifier }
		]
	},
	
}
