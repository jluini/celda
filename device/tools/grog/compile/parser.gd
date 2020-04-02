
class_name Parser

var root
var current

func _init():
	root = {
		precedence = -1,
		right_child = true,
	}
	current = root
	

#func parse_token(token) -> Dictionary:
#	if token.type == Grog.TokenType.Operator and token.content == "(":
#		read_token(token, 200)
#		assert(current.precedence == 200)
#		current.precedence = 1
#
#		return { result = true }
#
#	elif token.type == Grog.TokenType.Operator and token.content == ")":
#		while current.precedence > 1:
#			current = current.parent
#
#		if current.precedence < 1:
#			return { result = false, message = "no closing parentheses" }
#
#		pass
#
#		return { result = true }
#
#	# else ...
	
	
	#return { result = false, message = "not implemented" }

func open_parenthesis():
	read_token({}, 200)
	assert(current.precedence == 200)
	current.precedence = 1
	
	return { result = true }
	
func close_parenthesis():
	while current.precedence > 1:
		current = current.parent

	if current.precedence < 1:
		return { result = false, message = "no matching pharentesis" }
	
	assert(current.has("right")) 
	assert(current.right.has("parent")) 
	assert(current.right.parent == current) 
	assert(current.has("parent")) 
	assert(current.right_child)
	assert(current.parent.has("right"))
	assert(current.parent.right == current)
	
	# current is the matching opening pharentesis
	
	current.parent.right = current.right
	current.right.parent = current.parent
	
	# current is dereferenced
	
	current = current.parent
	
	return { result = true }
	
	
func read_token(token, precedence, right_associate = false):
	while true:
		var condition = current.precedence > precedence if right_associate else current.precedence >= precedence
		if condition:
			current = current.parent
		else:
			break
	
	assert(current.precedence <= precedence if right_associate else current.precedence < precedence)
	
	var new_node = {
		precedence = precedence,
		token = token,
		parent = current,
		right_child = true,
	}
	
	if current.has("right"):
		new_node.left = current.right
		assert(new_node.left.right_child)
		new_node.left.right_child = false
		current.erase("right")
	
	current.right = new_node
	current = new_node
	
	return { result = true }
	
func finish() -> Dictionary:
	while current.precedence > 1:
		current = current.parent
	
	if current.precedence == 1:
		return { result = false, message = "unclosed pharentesis" }
	
	return { result = true, root = root}
	
