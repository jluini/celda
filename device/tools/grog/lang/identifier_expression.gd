class_name IdentifierExpression

var indirection_level: int
var key: String

func _init(p_indirection_level: int = 0, p_key: String = ""):
	indirection_level = p_indirection_level
	key = p_key

func evaluate(game):
	var values = [key]
	var value = key
	
	for _i in range(indirection_level):
		if typeof(value) != TYPE_STRING:
			print("Trying to dereference value of type %s instead of string" % typeof(value))
			value = false
			break
		
		value = game.get_value(value)
		values.append(value)
	
	return value
