extends "res://tools/grog/base/base_client.gd"

export (AudioStream) var new_game_audio

onready var _room_parent = $viewport_container/viewport
onready var _side_menu = $ui/menu/side_menu
onready var _curtain = $ui/curtain_animation
onready var _inventory_base = $ui/inventory_base
onready var _inventory = $ui/inventory_base/inventory

onready var _speech_label: Label = $ui/speech

onready var _tabs = $ui/menu/tab_container/tabs
onready var _game_list = $ui/menu/tab_container/tabs/game_list/v_box_container
onready var _load_button = $ui/menu/side_menu/menu_buttons/load_game
onready var _quit_button = $ui/menu/side_menu/menu_buttons/quit
onready var _options_button = $ui/menu/side_menu/menu_buttons/options
onready var _back_button = $ui/menu/back_button

onready var _item_selector = $ui/selector

onready var _item_bubbles = $ui/item_actions

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
	
	_modular.broadcast("music", "start", ["menu"])
	
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
	_modular.broadcast("music", "stop", [])
	
	_play_sound(new_game_audio)
	
	_select_item(null)
	
	if _room_parent.get_child_count() > 0:
		make_empty(_room_parent)
	
	_curtain.play("closed") # immediately closes the curtain
	
	_speech_label.hide_speech() # immediately hides the speech
	
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
	
	_speech_label.start_speech(speech, color)
	
func _on_server_item_added(item: Object):
	_inventory.add_item(item)

func _on_server_item_removed(item: Object):
	if _get_selected_item() == item:
		_select_item(null)
		
	_inventory.remove_item(item)


func _on_server_curtain_up():
	_curtain.play("up")

func _on_server_curtain_down():
	_curtain.play("down")

func _on_server_tool_set(item, verb: String):
	_log_warning("_on_server_tool_set is not used anymore (id='%s', verb='%s')" % [item.get_id(), verb])
	
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
	else:
		# warning-ignore:return_value_discarded
		_try_to_skip()

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
	if _selected_item:
		if _selected_item.is_scene_item():
			# check bubble action
			var clicked_action : String = _item_bubbles.get_item_action_at(position)
			
			if clicked_action:
				if not game_instance.interact_request(_get_selected_item(), clicked_action):
					_log_warning("interaction ignored (scene item)")
				
				_select_item(null)
				
				return
	
	# then check inventory item click
	
	var clicked_item = _inventory.get_item_at(position)
	
	if clicked_item:
		if _selected_item == clicked_item:
			_select_item(null)
		else:
			_select_item(clicked_item)
		
		return
	
	# then check scene item click
	
	clicked_item = _get_scene_item_at(position)
	
	if clicked_item:
		if _selected_item and not _selected_item.is_scene_item():
			var _tool = _get_selected_item()
			var _with = clicked_item
			var _tool_verb = "usar_con" # TODO harcoded combination action
			
			if game_instance.interact_request(_with, _tool_verb, _tool):
				# successful combination
				_select_item(null)
			else:
				# failed combination
				pass # TODO notify the user
			
		else:
			var do_default_action: bool = _select_item(clicked_item, true)
			
			if do_default_action:
				if not game_instance.interact_request(clicked_item, game_instance.get_default_action()):
					_log_warning("default interaction ignored")
		
		return
	
	# finally issue a go-to request
	
	_select_item(null)
	
	if game_instance.is_player_in_room():
		game_instance.go_to_request(position)

###

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
				if _try_to_skip():
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
	
	get_tree().quit()

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

func _try_to_skip() -> bool:
	if not game_instance:
		_log_warning("unexpected call to _skip")
		return false
	
	if not game_instance.is_skip_enabled():
		return false
	
	var skip_accepted: bool = game_instance.skip_request()
	
	if skip_accepted:
		# TODO check text clearing
		_speech_label.end_speech()
		
		_select_item(null)
	else:
		_log_warning("skip request ignored")
	
	return skip_accepted

func _select_item(new_item, return_true_if_no_actions := false):
	if _selected_item == new_item:
		return false
	
	_selected_item = new_item
	
	_item_selector.hide()
	
	_item_bubbles.close()
	
	if not _selected_item:
		return false
	
	var actual_item = _get_selected_item()
	var is_scene_item = _selected_item.is_scene_item()
	
	if is_scene_item:
		var item_actions: Array = game_instance.get_item_actions(actual_item)
		var default_action: String = game_instance.get_default_action()
		
		# remove default action from list if present
		item_actions.erase(default_action)
		
		if return_true_if_no_actions and item_actions.empty():
			_selected_item = null
			return true
		
		_item_bubbles.position = _selected_item.position
		_item_bubbles.open()
	
	var rect : Rect2 = _selected_item.get_item_rect()
	_item_selector.show_rect(rect, not is_scene_item)
	
	return false

func _get_selected_item():
	if _selected_item and not _selected_item.is_scene_item():
		return _selected_item.get_item_instance()
	else:
		return _selected_item
