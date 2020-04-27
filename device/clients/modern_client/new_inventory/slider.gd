extends Control

enum SlideMode {
	Horizontal,
	Vertical
}

export (SlideMode) var slide_mode = SlideMode.Vertical
export (Vector2) var start_position
export (Vector2) var end_position
export (float) var delay = 0.5
export (float) var scale = 1.0
export (float) var amplitude = 0.07
export (float) var min_delta = 0.5

export (bool) var initially_at_start = true

export (bool) var fixed = false
export (bool) var start_enabled = true
export (bool) var end_enabled = true

var _position_is_initial: bool
var _position_is_changed: bool
var _current_level: float
var _moving: bool

func _ready():
	if not (start_enabled or end_enabled):
		print("No point is enabled")
		start_enabled = true
		end_enabled = true
	elif initially_at_start and not start_enabled:
		print("Bad configuration 1")
		start_enabled = true
	elif not initially_at_start and not end_enabled:
		print("Bad configuration 2")
		end_enabled = true
	
	_position_is_initial = initially_at_start
	_position_is_changed = false
	_current_level = 0.0 if _position_is_initial else 1.0
	_moving = false
	
	# TODO why does this fail??? initialization problems?
	_set_level(_current_level)

func _set_level(new_level: float):
	_current_level = new_level
	var init_pos = start_position + new_level * (end_position - start_position)
	rect_position = init_pos

func slide(delta: Vector2) -> bool:
	if fixed:
		return _position_is_initial
	
	$tween.stop_all() # self, "_set_level"
	
	_moving = true
	
	var dy: float
	var diff: float
	if slide_mode == SlideMode.Vertical:
		dy = delta.y
		diff = end_position.y - start_position.y
	else:
		dy = delta.x
		diff = end_position.x - start_position.x
	
	dy *= scale
		
	if not _position_is_initial:
		dy = -dy
	
	dy /= diff
	
	# now it's normalized
	
	dy = _ease(dy)
	
	# now it's contracted
	
	_set_level(dy if _position_is_initial else 1.0 - dy)
	
	_position_is_changed = start_enabled and end_enabled and dy >= min_delta
	
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
	var scale = abs(final_value - _current_level)
	if scale == 0:
		return
		
	$tween.interpolate_method(
		self,
		"_set_level",
		_current_level,
		final_value,
		delay * scale,
		Tween.TRANS_BACK,
		Tween.EASE_OUT
	)
	$tween.start()
	
func _ease(value: float) -> float:
	var min_value = 0.0 if start_enabled else 1.0
	var max_value = 1.0 if end_enabled else 0.0
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

