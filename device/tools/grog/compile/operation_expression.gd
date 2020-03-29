class_name OperationExpression

var left
var operator
var right

func _init(p_left, p_operator, p_right):
	left = p_left
	operator = p_operator
	right = p_right

func evaluate(_game):
	# TODO check types
	match operator:
		"+":
			return left.evaluate(_game) + right.evaluate(_game)
		"-":
			return left.evaluate(_game) - right.evaluate(_game)
		"<":
			return left.evaluate(_game) < right.evaluate(_game)
		">":
			return left.evaluate(_game) > right.evaluate(_game)
		_:
			push_error("Operator %s not implemented" % operator)
			return false
