extends Resource

class_name Routine

export (String) var trigger_name
export (Array) var statements
export (bool) var telekinetic
export (String) var pattern

func _init(_trigger_name := "", _statements := [], _telekinetic := false, _pattern := ""):
	trigger_name = _trigger_name
	statements = _statements
	telekinetic = _telekinetic
	pattern = _pattern

func is_telekinetic() -> bool:
	return telekinetic

func has_pattern() -> bool:
	return pattern != ""
