class_name InverseNumberExpression

var content

func _init(p_content = null):
	content = p_content

func evaluate(_game):
	var inner = content.evaluate(_game)

	if typeof(inner) != TYPE_INT:
		print("Invalid type %s for unary operator '-'" % [Grog._typestr(inner)])
		return false
	
	return - inner
	
