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
	
	match operator:
		"+":
			if typeof(left_value) != TYPE_INT and typeof(left_value) != TYPE_STRING:
				print("Invalid type %s for operator %s" % [Grog._typestr(left_value), operator])
				return 0
			if typeof(right_value) != TYPE_INT and typeof(right_value) != TYPE_STRING:
				print("Invalid type %s for operator %s" % [Grog._typestr(right_value), operator])
				return 0
			if typeof(left_value) != typeof(right_value):
				print("Invalid types %s and %s for operator %s" % [Grog._typestr(left_value), Grog._typestr(right_value), operator])
				return 0
			
			return left_value + right_value
				
		"-", "<", ">":
			if typeof(left_value) != TYPE_INT or typeof(right_value) != TYPE_INT:
				print("Invalid types %s and %s for operator %s" % [Grog._typestr(left_value), Grog._typestr(right_value), operator])
				return 0
			
			if operator == "+":
				return left_value + right_value
			elif operator == "-":
				return left_value - right_value
			elif operator == "<":
				return left_value < right_value
			else:
				return left_value > right_value
		"=":
			if typeof(left_value) != typeof(right_value):
				print("Uncompatible types for equality operator (%s and %s)" % [Grog._typestr(left_value), Grog._typestr(right_value)])
				return 0
			
			if typeof(left_value) != TYPE_INT and typeof(left_value) != TYPE_BOOL and typeof(left_value) != TYPE_STRING:
				print("Unexpected type for equality operator: %s. Continuing." % Grog._typestr(left_value))
			
			return left_value == right_value
		
		"and", "or":
			if typeof(left_value) != TYPE_INT and typeof(left_value) != TYPE_BOOL:
				print("Unexpected type for %s operator: %s. Continuing." % [operator, Grog._typestr(left_value)])
			if typeof(right_value) != TYPE_INT and typeof(right_value) != TYPE_BOOL:
				print("Unexpected type for %s operator: %s. Continuing." % [operator, Grog._typestr(right_value)])
				
			if operator == "and":
				return left_value and right_value
			else:
				return left_value or right_value
			
		_:
			push_error("Operator %s not implemented" % operator)
			return false
