class_name TestCase

var global_errors = []
var test_errors = []

func test():
	for method in self.get_method_list():
		if method.name.begins_with("test") and method.name != "test":
			test_errors = []
			self.set_up()
			self.call(method.name)
			self.tear_down()
			
			if test_errors:
				print("Test '%s' failed" % method.name)
				
				while test_errors:
					var next_error = test_errors.pop_front()
					global_errors.append({ test=method.name, msg = next_error })
					print(next_error)
			else:
				print("Test '%s' OK" % method.name)
				
			

func set_up():
	pass

func tear_down():
	pass


# Asserts

func assert_true(condition, message = "") -> bool:
	if typeof(condition) != TYPE_BOOL:
		print("Warning: condition is not boolean")
	
	if not condition:
		if not message:
			message = "Condition is not true"
		test_errors.append(message)
		
		return false
	
	return true

func assert_equals(actual, expected, message = "") -> bool:
	if typeof(actual) != typeof(expected):
		if not message:
			message = "type not equal %s != %s" % [_str(actual), _str(expected)]
		test_errors.append(message)
		return false
	
	if not message:
		message = "not equal %s != %s" % [_str(actual), _str(expected)]
		
	return assert_true(actual == expected, message)

func _str(obj):
	var max_length = 10
	var ret: String = str(obj)
	
	if ret.length() > max_length:
		ret = ret.substr(0, max_length - 3)
		ret += "..."
	
	return ret
