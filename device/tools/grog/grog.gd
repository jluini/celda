class_name Grog

const commands = {
	load_room = {
		subject = GrogCompiler.SubjectType.None,
		required_params = [
			GrogCompiler.ParameterType.StringType
		]
	},
	enable_input = {
		subject = GrogCompiler.SubjectType.None,
		required_params = []
	},
	disable_input = {
		subject = GrogCompiler.SubjectType.None,
		required_params = []
	},
	wait = {
		subject = GrogCompiler.SubjectType.None,
		required_params = [
			GrogCompiler.ParameterType.FloatType
		],
		named_params = [
			{ name = "skippable", required = false, type = GrogCompiler.ParameterType.BooleanType }
		]
	},
	say = {
		subject = GrogCompiler.SubjectType.Optional,
		required_params = [
			GrogCompiler.ParameterType.StringTokenType
		],
		named_params = [
			{ name = "duration", required = false, type = GrogCompiler.ParameterType.FloatType },
			{ name = "skippable", required = false, type = GrogCompiler.ParameterType.BooleanType }
		]
	},
	walk = {
		subject = GrogCompiler.SubjectType.Required,
		required_params = [],
		named_params = [
			{ name = "to", required = true, type = GrogCompiler.ParameterType.StringType }
		]
	},
	
	# end the game
	end = {
		subject = GrogCompiler.SubjectType.None,
		required_params = []
	},
	
	# set value to global variable
	# (currently only bool values, they are false by default)
	set = {
		subject = GrogCompiler.SubjectType.None,
		required_params = [
			GrogCompiler.ParameterType.StringType,
			GrogCompiler.ParameterType.BooleanType
		]
	},
	
	# enable/disable item
	# (they are active by default and can be disabled to hide them and prevent interaction)
	enable = {
		subject = GrogCompiler.SubjectType.Required,
		required_params = []
	},
	disable = {
		subject = GrogCompiler.SubjectType.Required,
		required_params = []
	},
	
	# add/remove inventory item
	add = {
		subject = GrogCompiler.SubjectType.None,
		required_params = [
			GrogCompiler.ParameterType.StringType,
		]
	},
	remove = {
		subject = GrogCompiler.SubjectType.None,
		required_params = [
			GrogCompiler.ParameterType.StringType,
		]
	},
	
}

#	@PUBLIC

static func compile(script: Resource):
	var compiler = load("res://tools/grog/grog_compiler.gd").new()
	compiler.set_grammar({ commands = commands })
	return compiler.compile(script)

static func compile_text(code: String):
	var compiler = load("res://tools/grog/grog_compiler.gd").new()
	compiler.set_grammar({ commands = commands })
	return compiler.compile_text(code)
