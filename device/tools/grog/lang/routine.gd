extends Resource

class_name Routine

export (String) var trigger_name
export (Array) var statements

func _init(_trigger_name = "", _statements = []):
	trigger_name = _trigger_name
	statements = _statements

func is_telekinetic():
	return false
