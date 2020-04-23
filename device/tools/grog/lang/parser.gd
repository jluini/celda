
class_name Parser

var root: Dictionary
var current: Dictionary

func _init():
	root = {
		precedence = -1,
		token = { content = "#root#" },
		right_child = true,
		enable_right = true,
		enable_left = false
	}
	current = root

func open_parenthesis():
	var r = read_token({ content = "(" }, 200, false, true)
	if not r.result:
		return r
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
	
	
func read_token(token: Dictionary, precedence: int, enable_left: bool, enable_right: bool): #, right_associate = false):
	var right_associate = false
	
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
		enable_left = enable_left,
		enable_right = enable_right
	}
	
	if not current.enable_right:
		return { result = false, message = "token '%s' can't have right child; reading %s" % [current.token.content, token.content] }
	
	if current.has("right"):
		if not enable_left:
			return { result = false, message = "token '%s' can't have left child" % [token.content] }
		new_node.left = current.right
		assert(new_node.left.right_child)
		new_node.left.right_child = false
		var _r = current.erase("right")
	
	current.right = new_node
	current = new_node
	
	return { result = true }
	
func finish() -> Dictionary:
	while current.precedence > 1:
		current = current.parent
	
	if current.precedence == 1:
		return { result = false, message = "unclosed pharentesis" }
	
	return { result = true, root = root}
	
