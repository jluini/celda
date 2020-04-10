extends "res://tools/grog/base_client.gd"

enum InputState {
	None,
	Clicking,
	Holding,
	Dragging,
}
var _input_state = InputState.None
var _input_position = null

export (NodePath) var _room_parent_path
export (float) var hold_delay = 0.625

onready var _room_parent = get_node(_room_parent_path)

onready var _curtain = $curtain
onready var _timer = $timer
onready var _item_menu = $item_menu
onready var _item_actions = $item_menu/actions
onready var _item_name = $item_menu/item_name

var _current_item = null

var _actions = []

func _on_init():
	if _room_parent.get_child_count() > 0 :
		print("Room place is not empty! Clearing it.")
		make_empty(_room_parent)
	
	var ret = server.start_game_request(_room_parent)
	
	if not ret:
		print("Couldn't start game")
		_end_game()
	# else signal game_started was just received (or it will now)
	
	_curtain.play("closed")
	_item_menu.hide()
	
	#warning-ignore:return_value_discarded
	_item_actions.connect("on_element_selected", self, "_on_action_selected")
	#warning-ignore:return_value_discarded
	_item_actions.connect("on_element_deselected", self, "_on_action_deselected")
	
	for action_name in data.actions:
		var new_elem = _item_actions.add_element(action_name)
		
		_actions.append({
			action_name = action_name,
			menu_element = new_elem
		})

func _on_start():
	pass
	
func _on_end():
	pass

####

func _unhandled_input(event):
	if not server or not server.is_playing():
		return
	
	if event is InputEventMouseButton:
		var mouse_position: Vector2 = event.position
		
		if event.button_index == BUTTON_LEFT:
			_timer.stop() # doing always
		
			if event.pressed:
				if _input_state == InputState.None:
					_set_input_state(InputState.Clicking, mouse_position)
					_timer.start(hold_delay)
				else:
					if _input_state == InputState.Holding:
						_end_hold()
					elif _input_state == InputState.Dragging:
						# TODO continuing drag at new position!
						_drag(mouse_position)
					else: # _input_state == InputState.Clicking:
						pass
					
					_set_input_state(InputState.None, null)
			else:
				if _input_state == InputState.Clicking:
					if mouse_position.is_equal_approx(_input_position):
						_left_click(mouse_position)
					_set_input_state(InputState.None, null)
				
				elif _input_state == InputState.Holding:
					if mouse_position.is_equal_approx(_input_position):
						_lock_hold()
					else:
						_end_hold()
					
					_set_input_state(InputState.None, null)
				
				elif _input_state == InputState.Dragging:
					_end_drag(mouse_position)
					_set_input_state(InputState.None, null)
		
	elif event is InputEventMouseMotion:
		var mouse_position: Vector2 = event.position
		
		if _input_state in [InputState.Clicking, InputState.Holding]:
			_timer.stop()
			_start_drag(mouse_position)
			_set_input_state(InputState.Dragging, mouse_position)
		elif _input_state == InputState.Dragging:
			_drag(mouse_position)
		#else: # _input_state == InputState.None

###

func _left_click(position: Vector2):
	if _current_item != null:
		_select_item(null)
		return
	
	var world_position = position
	
	var item = _get_scene_item_at(world_position)
	if item:
		server.interact_request(item, data.default_action)
	
	elif server.is_navigable(world_position):
		$cursor.position = world_position
		$cursor/animation.play("default")
		$cursor/animation.play("go")
		server.go_to_request(world_position)

func _start_hold(position: Vector2):
	if _current_item != null:
		_select_item(null)
	
	var item = _get_scene_item_at(position)
	
	if item:
		_select_item(item)
 
func _lock_hold():
	pass # print("LOCK HOLD")
	
func _end_hold():
	pass # print("END HOLD")

func _start_drag(position: Vector2):
	pass # print("START DRAG: %s" % position)

func _drag(position: Vector2):
	pass # print("DRAG: %s" % position)
	
func _end_drag(position: Vector2):
	pass # print("END DRAG: %s" % position)

#	@SERVER EVENTS

func _on_server_input_enabled():
	pass # print("_on_server_input_enabled")
	
func _on_server_input_disabled():
	pass # print("_on_server_input_disabled")

func _on_server_room_loaded(_room):
	pass # print("_on_server_room_loaded")

func _on_item_enabled(item):
	pass

func _on_item_disabled(item):
	if _current_item == item:
		_select_item(null)
	

func _on_server_wait_started(_duration: float, skippable: bool):
	pass # print("_on_server_wait_started")

func _on_server_wait_ended():
	pass # print("_on_server_wait_ended")

func _on_server_say(subject: Node, speech: String, _duration: float, skippable: bool):
	pass # print("_on_server_say")

func _on_server_item_added(item):
	pass # print("_on_server_item_added")

func _on_server_item_removed(item: Node):
	pass # print("_on_server_item_removed")
	
func _on_server_tool_set(new_tool, verb_name: String):
	pass # print("_on_server_tool_set")

func _on_server_curtain_up():
	_curtain.play("up")
	
func _on_server_curtain_down():
	_curtain.play("down")
	
###

func _on_quit_button_pressed():
	if not server:
		return
	server.stop_request()

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
	_start_hold(_input_position)

###

func _select_item(_new_item):
	if _current_item == _new_item:
		return
	
	if _current_item:
		_current_item.modulate = Color.white
	
	_current_item = _new_item
	if _new_item:
		_item_name.text = capitalize_first(_item_name(_new_item))
		
		_item_actions.deselect()
		
		for i in range(_actions.size()):
			var action_name = _actions[i].action_name
			var menu_element = _actions[i].menu_element
			
			if not _new_item.has_action(action_name):
				menu_element.hide()
			else:
				menu_element.show()
		
		_item_menu.show()
		
		_new_item.modulate = Color(0.7, 1 ,0.7)
	else:
		_item_menu.hide()
		


func _on_close_menu_button_pressed():
	_select_item(null)

####

func _on_action_selected(_old_action, new_action: Node):
	var item = _current_item
	var action = new_action.target
	
	_select_item(null)
	
	server.interact_request(item, action)
	

func _on_action_deselected(_old_view):
	pass # print("_on_action_deselected(%s)" % _old_view)
