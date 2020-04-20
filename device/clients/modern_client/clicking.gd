extends Control

signal click  # (position)

signal start_hold # (position)
signal lock_hold  # ()
signal end_hold # ()

signal start_drag # (position)
signal drag # (position)
signal end_drag # (position)


export (float) var hold_delay = 0.625

onready var _timer = $timer

enum InputState {
	None,
	Clicking,
	Holding,
	Dragging,
}

var _input_state = InputState.None
var _input_position = null

#func _unhandled_input(event):
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		var mouse_position: Vector2 = event.position
		
		_timer.stop() # doing always
	
		if event.pressed:
			if _input_state == InputState.None:
				_set_input_state(InputState.Clicking, mouse_position)
				_timer.start(hold_delay)
			else:
				if _input_state == InputState.Holding:
					emit_signal("end_hold")
				elif _input_state == InputState.Dragging:
					# TODO continuing drag at new position!
					emit_signal("drag", mouse_position)
				else: # _input_state == InputState.Clicking:
					pass
				
				_set_input_state(InputState.None, null)
		else:
			if _input_state == InputState.Clicking:
				if mouse_position.is_equal_approx(_input_position):
					emit_signal("click", mouse_position)
				
				_set_input_state(InputState.None, null)
			
			elif _input_state == InputState.Holding:
				if mouse_position.is_equal_approx(_input_position):
					emit_signal("lock_hold")
				else:
					emit_signal("end_hold")
				
				_set_input_state(InputState.None, null)
			
			elif _input_state == InputState.Dragging:
				emit_signal("end_drag", mouse_position)
				_set_input_state(InputState.None, null)
		
	elif event is InputEventMouseMotion:
		var mouse_position: Vector2 = event.position
		
		if _input_state in [InputState.Clicking, InputState.Holding]:
			_timer.stop()
			emit_signal("start_drag", mouse_position)
			_set_input_state(InputState.Dragging, mouse_position)
		elif _input_state == InputState.Dragging:
			emit_signal("drag", mouse_position)
		#else: # _input_state == InputState.None
	
###

func _set_input_state(_new_state, _mouse_pos):
	var old_state = _input_state
	
	_input_position = _mouse_pos
	
	if _new_state == old_state:
		print("Unchanged %s" % InputState.keys()[_new_state])
		return
	_input_state = _new_state

func _on_timer_timeout():
	if _input_state != InputState.Clicking:
		print("Unexpected timeout")
		return
	
	_set_input_state(InputState.Holding, _input_position)
	emit_signal("start_hold", _input_position)
