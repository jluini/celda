class_name OperationExpression

var left
var operator
var right

func _init(p_left, p_operator, p_right):
	left = p_left
	operator = p_operator
	right = p_right

func evaluate(_game):
	var left_value = left.evaluate(_game)
	var right_value = right.evaluate(_game)
	
	# TODO check types
	match operator:
		"+", "-", "<", ">":
			if typeof(left_value) != TYPE_INT or typeof(right_value) != TYPE_INT:
				print("Invalid types %s and %s for operator %s" % [_game._typestr(left_value), _game._typestr(right_value), operator])
				return 0
			
			if operator == "+":
				return left_value + right_value
			elif operator == "-":
				return left_value - right_value
			elif operator == "<":
				return left_value < right_value
			else:
				return left_value > right_value
		
		_:
			push_error("Operator %s not implemented" % operator)
			return false
