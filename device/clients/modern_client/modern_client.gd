extends "res://tools/grog/base/base_client.gd"

onready var _room_parent = $viewport_container/viewport
onready var _side_menu = $ui/menu/side_menu
onready var _curtain = $ui/curtain_animation
onready var _inventory_base = $ui/inventory_base
onready var _inventory = $ui/inventory_base/inventory

onready var _text: Label = $ui/text

onready var _tabs = $ui/menu/tab_container/tabs
onready var _game_list = $ui/menu/tab_container/tabs/game_list/v_box_container
onready var _load_button = $ui/menu/side_menu/menu_buttons/load_game
onready var _quit_button = $ui/menu/side_menu/menu_buttons/quit
onready var _options_button = $ui/menu/side_menu/menu_buttons/options
onready var _back_button = $ui/menu/back_button

onready var _item_selector = $ui/selector
onready var _action_list = $ui/action_list

enum ClientState {
	# no game yet (menu is open)
	NoGame,
	
	# game is starting (menu is closing and the user can't move it)
	Starting,
	
	# a game is being played, either running (menu closed) or paused (menu open)
	# the user can freely move the menu (pausing/unpausing the game)
	Playing
}
var _client_state: int = ClientState.NoGame
var _menu_is_open := true

var _pressed_button = null

var _initial_drag_position: Vector2

enum DragState {
	None,
	Dragging
}
var _drag_state = DragState.None


var _selected_item = null

func _on_init():
	_back_button.hide()

	_tabs.show_named("title")

	_hide_group("only_if_playing")
	
	#Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
	_side_menu.connect("completed", self, "_on_menu_completed")

func _on_menu_completed():
	match _client_state:
		ClientState.Starting:
			# menu is fully closed
			# start the game and free the menu for manipulation
			
			_client_state = ClientState.Playing
			
			_menu_is_open = false
			
			var ret = game_instance.start_game_request(_room_parent)
		
			if not ret:
				_log_error("couldn't start playing game")
				
				# TODO try loading an invalid game and recover from that
			
			_show_group("only_if_playing")

func _start():
#	if _client_state != ClientState.NoGame:
#		_log_warning("unexpected state %s" % _client_state_str())
#		return
	_item_selector.hide()
	_action_list.hide()
	_select_item(null)
	
	if _room_parent.get_child_count() > 0:
		make_empty(_room_parent)
	
	_text.text = ""
	_curtain.play("closed") # just in case
	
	_client_state = ClientState.Starting
	
	_side_menu.end_enabled = true
	_side_menu.set_state(false)
	
	_inventory.clear()
	
	# game will actually start when menu completes closing

func _on_start():
	pass

func _on_end():
	pass

####


#	@SERVER EVENTS

func _on_server_room_loaded(_room):
	pass

func _on_item_enabled(_item):
	pass

func _on_item_disabled(item):
	if item == _selected_item:
		print("unloading selected item '%s'!!" % item.get_key())
	

func _on_server_say(subject: Node, speech: String, _duration: float, _skippable: bool):
	var color = subject.get_color() if subject else game_instance.get_default_color()
	
	_text.text = speech
	_text.modulate = color

func _on_server_item_added(item: Object):
	_inventory.add_item(item)

func _on_server_item_removed(item: Object):
	_inventory.remove_item(item)

#	if _current_item == item:
#		_select_item(null)

func _on_server_curtain_up():
	_curtain.play("up")

func _on_server_curtain_down():
	_curtain.play("down")

### Clicking ui events

func _on_ui_click(position: Vector2):
	if _client_state == ClientState.Starting:
		return
	
	if _menu_is_open:
		_menu_click(position)
		return
	
	# else there must be a game_instance
	
	if game_instance.is_ready():
		_ready_click(position)
	elif _skip():
		pass
	else:
		_log_debug("click ignored")

func _on_ui_start_hold(_position: Vector2):
	pass

func _on_ui_lock_hold():
	pass

func _on_ui_end_hold():
	pass

func _on_ui_start_drag(position: Vector2):
	if _drag_state != DragState.None:
		_log_warning("Unexpected drag state '%s'" % DragState.keys()[_drag_state])
		return

	_initial_drag_position = position
	_drag_state = DragState.Dragging

func _on_ui_drag(position: Vector2):
	if _drag_state != DragState.Dragging:
		return
	
	# don't allow sliding while Starting
	if _client_state == ClientState.Starting:
		return
	
	var delta = position - _initial_drag_position
	
	var x_drag := abs(delta.x) > abs(delta.y)

	if x_drag:
		#delta.y = 0
		#_initial_drag_position.y = position.y
		
		var should_be_paused = _side_menu.slide(delta)
		
		if _client_state == ClientState.Playing:
			assert(game_instance)
			if should_be_paused != game_instance.is_paused():
				if should_be_paused:
					game_instance.pause_request()
				else:
					game_instance.unpause_request()
#	else:
#		delta.x = 0
#		_initial_drag_position.x = position.x
#	var _inventory_is_open = _inventory_base.slide(delta)

func _on_ui_end_drag(_position: Vector2):
	if _drag_state != DragState.Dragging:
		return

	_menu_is_open = _side_menu.drop()
	#_inventory_base.drop()
	
	_drag_state = DragState.None

### Client clicking

func _menu_click(position: Vector2) -> void:
	var clicked_button: Control = _get_menu_button_at(position)
	
	if not clicked_button:
		return
	
	match clicked_button.name:
		"continue":
			if _client_state != ClientState.Playing:
				_log_warning("unexpected 'continue' click")
				return
			
			game_instance.unpause_request()
			_menu_is_open = false
			_side_menu.set_state(false)
			
		"save_game":
			var save_result = server.save_game()
			
			if save_result.valid:
				_log_debug("game saved!")
			else:
				_log_error("couldn't save")
		
		"new_game":
			_new_game_from("")
			
		"load_game":
			_on_load_game_pressed()
			
		"options":
			_close_all()
			_modular.show_modules()
		
		"quit":
			_on_quit_pressed()
			
		_:
			_log_warning("unknown button '%s' clicked" % clicked_button.name)

func _ready_click(position: Vector2) -> void:
	# check action click first
	var clicked_action : String = _action_list.get_item_action_at(position) if _selected_item else ""
	
	if clicked_action:
		if not game_instance.interact_request(_selected_item, clicked_action):
			_log_warning("interaction ignored")
		
		_select_item(null)
		
		return
	
	# then check inventory item click
	
	var clicked_item = _get_inventory_item_at(position)
	
	if clicked_item:
		_select_item(clicked_item)
		
		print("clicked inventory item '%s'" % clicked_item.get_key())
		
		#
#		if not game_instance.interact_request(clicked_item):
#			_log_warning("interaction ignored")
		
		return
	
	# then check scene item click
	
	clicked_item = _get_scene_item_at(position)
	
	if clicked_item:
		_select_item(clicked_item)
		
		if not game_instance.interact_request(clicked_item):
			_log_warning("interaction ignored")
		
		return
	
	# finally issue a go-to request
	
	_select_item(null)
	game_instance.go_to_request(position)

###

func _get_inventory_item_at(position: Vector2):
	var ret = _inventory.get_item_at(position)
	
	return ret

func _on_continue_pressed():
	pass # Replace with function body.

func _on_save_game_pressed():
	pass # Replace with function body.

func on_load_game_requested(filename: String):
	_new_game_from(filename)

func _on_new_game_pressed():
	_new_game_from("")

func _new_game_from(filename: String):
#	if game_instance:
#		_log_warning("replay not implemented!")
#		return

	var start_game_result = _start_game_from(filename)

	if start_game_result.valid:
		_start()
	else:
		_log_error("couldn't start game")
		_log_error(start_game_result.message)


func _on_load_game_pressed():
	if _pressed_button == _load_button:
		return

	_close_all()

	_load_button.set_pressed(true)
	_pressed_button = _load_button

	var saved_games_result = server.get_saved_games()
	var saved_games: Array = saved_games_result.saved_games

	# TODO check saved_games_result.valid and show message if there's error

	_back_button.show()
	_game_list.init(self, saved_games)
	_game_list.show()
	_tabs.show_named("game_list")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_ESCAPE:
				if game_instance and _skip():
					# TODO only handled in this case?
					get_tree().set_input_as_handled()

			KEY_S:
				var save_result = server.save_game()

				if save_result.valid:
					_log_debug("game saved!")
				else:
					_log_error("couldn't save")

			KEY_D:
				pass


func _close_all():
	if _pressed_button:
		_pressed_button.set_pressed(false)

		if _pressed_button == _load_button:
			_go_back()

		_pressed_button = null

func _on_quit_pressed():
	var already_quitting = _pressed_button == _quit_button
	_close_all()

	if not already_quitting:
		_quit_button.set_pressed(true)
		_pressed_button = _quit_button

	# TODO!!
	#get_tree().quit()


func _on_back_button_pressed():
	_close_all()

func _go_back():
	_tabs.show_named("title")
	_back_button.hide()

func _get_menu_buttons():
	return $ui/menu/side_menu/menu_buttons.get_children()

func _get_menu_button_at(position: Vector2) -> Control:
	for button_node in _get_menu_buttons():
		var button = button_node as Control
		if button.visible and button.get_rect().has_point(position):
			return button
	
	return null

func _hide_group(group_name: String):
	for n in get_tree().get_nodes_in_group(group_name):
		n.hide()

func _show_group(group_name: String):
	for n in get_tree().get_nodes_in_group(group_name):
		n.show()

func _client_state_str(state: int = -1):
	if state == -1:
		state = _client_state
	return ClientState.keys()[state]

func _skip() -> bool:
	if not game_instance:
		_log_warning("unexpected call to _skip")
		return false
	
	var skip_accepted: bool = game_instance.skip_request()
	if skip_accepted:
		_text.text = ""
		_select_item(null)
		
	return skip_accepted

func _select_item(new_item):
	if _selected_item == new_item:
		if _selected_item:
			_log_warning("item '%s' is already selected" % (new_item.get_key() if new_item else "null"))
			# TODO return or refresh action list in this case?
		return
	
	if _selected_item:
		pass # unselect previous item
	
	_selected_item = new_item
	
	if _selected_item:
		var rect : Rect2 = _selected_item.get_rect()
		
		_item_selector.set_position(rect.position)
		_item_selector.set_size(rect.size)
		
		_item_selector.show()
		
		var item_actions: Array = server.game_script.get_item_actions(_selected_item)
		
		# removing default action from list
		item_actions.erase(server.game_script.default_action)
		
		_action_list.set_item(_selected_item, item_actions)
		_action_list.show()
		
	else:
		_item_selector.hide()
		_action_list.hide()
	
