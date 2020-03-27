class_name GlobalVarIsTrueCondition

var var_name: String

func _init(_var_name: String):
	var_name = _var_name

func evaluate(game) -> bool:
	return game.get_global(var_name)
