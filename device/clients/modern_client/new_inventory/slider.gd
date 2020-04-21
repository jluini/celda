extends Control

enum SlideMode {
	Horizontal,
	Vertical
}

export (SlideMode) var slide_mode = SlideMode.Vertical
export (Vector2) var initial_position
export (Vector2) var other_position
export (float) var scale = 1.0
export (float) var amplitude = 1.0
export (float) var min_delta = 0.5

var _position_is_initial: bool = true
var _position_is_changed: bool = false
var _current_level: float
var _moving = false

func _ready():
	#_position_is_minimum = true
	_set_level(0.0) # if _position_is_minimum else 1.0)

func _set_level(new_level: float):
	_current_level = new_level
	rect_position = initial_position + new_level * (other_position - initial_position)

func slide(delta: Vector2) -> bool:
	_moving = true
	
	var dy: float
	var diff: float
	if slide_mode == SlideMode.Vertical:
		dy = delta.y
		diff = other_position.y - initial_position.y
	else:
		dy = delta.x
		diff = other_position.x - initial_position.x
	
	dy *= scale
		
	if not _position_is_initial:
		dy = -dy
	
	dy /= diff
	
	# now it's normalized
	
	dy = _ease(dy)
	
	# now it's contrated
	
	_set_level(dy if _position_is_initial else 1.0 - dy)
	
	_position_is_changed = dy >= min_delta
	
	return not _position_is_initial if _position_is_changed else _position_is_initial

func drop():
	if not _moving:
		return
	
	_moving = false
	
	if _position_is_changed:
		_position_is_initial = not _position_is_initial
		_position_is_changed = false
	
	if _position_is_initial:
		_interpolate_position(0.0)
	else:
		_interpolate_position(1.0)

func _interpolate_position(final_value: float):
	$tween.interpolate_method(
		self,
		"_set_level",
		_current_level,
		final_value,
		0.3,
		Tween.TRANS_BACK,
		Tween.EASE_OUT
	)
	$tween.start()
	
func _ease(value: float) -> float:
	var min_value = 0.0
	var max_value = 1.0
	var a = amplitude
	
	if value <= min_value:
		return min_value - log((min_value - value) / a + 1) * a
	elif value >= max_value:
		return max_value + log((value - max_value) / a + 1) * a
	else:
		return value

func close():
	_set_state(true)
	
func open():
	_set_state(false)
	
func toggle():
	if _moving:
		return
	
	if _position_is_initial:
		open()
	else:
		close()
	

func _set_state(new_value):
	if _moving:
		return
	
	if _position_is_initial == new_value:
		return
	
	_position_is_initial = new_value
	_interpolate_position(0.0 if _position_is_initial else 1.0)

