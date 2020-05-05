class_name NegatedBoolExpression

var content

func _init(p_content = null):
	content = p_content

func evaluate(_game):
	var inner = content.evaluate(_game)
	
	if typeof(inner) != TYPE_BOOL:
		print("Invalid type %s operator not" % [Grog._typestr(inner)])
		return false
	
	return not inner
