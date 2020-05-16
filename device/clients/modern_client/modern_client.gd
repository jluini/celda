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

var _menu_is_open := true

var _pressed_button = null

var _initial_drag_position: Vector2

enum DragState {
	None,
	Dragging
}
var _drag_state = DragState.None

func _on_init():
	_back_button.hide()

	_tabs.show_named("title")

	_hide_group("only_if_playing")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)


func _start():
	if _room_parent.get_child_count() > 0 :
		make_empty(_room_parent)
	
	_menu_is_open = false
	_side_menu.set_state(false)
	_side_menu.fixed = false
	_side_menu.end_enabled = true

	_text.text = ""

	_curtain.play("closed")

	# TODO wait until menu is fully closed

	var ret = game_instance.start_game_request(_room_parent)

	if not ret:
		_log_error("couldn't start playing game")
		_end_game()

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
	pass

func _on_server_say(subject: Node, speech: String, _duration: float, _skippable: bool):
	var color = subject.color if subject else game_instance.get_default_color()

	_text.text = speech
	_text.modulate = color

func _on_server_item_added(item: Node):
	_inventory.add_item(item)

func _on_server_item_removed(item: Node):
	_inventory.remove_item(item)

#	if _current_item == item:
#		_select_item(null)

func _on_server_curtain_up():
	_curtain.play("up")

func _on_server_curtain_down():
	_curtain.play("down")

### Clicking ui events

func _on_ui_click(position: Vector2):
	if _menu_is_open:
		var clicked_button: Control = _get_menu_button_at(position)
		
		if clicked_button:
			clicked_button.click()
	
	else:
		assert(game_instance)
		
		if game_instance.is_ready():
			game_instance.go_to_request(position)

func _on_ui_start_hold(position: Vector2):
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

	var delta = position - _initial_drag_position

	if abs(delta.x) > abs(delta.y):
		delta.y = 0
		_initial_drag_position.y = position.y
	else:
		delta.x = 0
		_initial_drag_position.x = position.x

	var should_be_paused = _side_menu.slide(delta)
	var _inventory_is_open = _inventory_base.slide(delta)

	if game_instance and should_be_paused != game_instance.is_paused():
		if should_be_paused:
			game_instance.pause_request()
		else:
			game_instance.unpause_request()


func _on_ui_end_drag(_position: Vector2):
	if _drag_state != DragState.Dragging:
		return

	_menu_is_open = _side_menu.drop()
	_inventory_base.drop()

	_drag_state = DragState.None

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
	if game_instance:
		_log_warning("Replay not implemented!")
		return

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
				if game_instance and game_instance.skip_request():
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


func _on_options_pressed():
	_close_all()
	_modular.show_modules()

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
