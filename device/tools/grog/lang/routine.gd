extends Resource

class_name Routine

export (String) var trigger_name
export (Array) var statements
export (bool) var telekinetic

func _init(_trigger_name = "", _statements = [], _telekinetic = false):
	trigger_name = _trigger_name
	statements = _statements
	telekinetic = _telekinetic

func is_telekinetic():
	return telekinetic
