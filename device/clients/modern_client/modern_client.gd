extends "res://tools/grog/base/base_client.gd"

signal item_selected # (item)
signal item_deselected # (item)

onready var _room_parent = $viewport_container/viewport
onready var _side_menu = $ui/menu/side_menu
onready var _curtain = $ui/curtain_animation
onready var _inventory_base = $ui/inventory_base
onready var _inventory = $ui/inventory_base/inventory

onready var _text: Label = $ui/text

onready var _status: Label = $ui/status

onready var _tabs = $ui/menu/tab_container/tabs
onready var _game_list = $ui/menu/tab_container/tabs/game_list/v_box_container
onready var _load_button = $ui/menu/side_menu/VBoxContainer/load_game
onready var _quit_button = $ui/menu/side_menu/VBoxContainer/quit
onready var _options_button = $ui/menu/side_menu/VBoxContainer/options
onready var _back_button = $ui/menu/back_button

var _pressed_button = null

var _current_item = null

var _initial_drag_position: Vector2

enum DragState {
	None,
	Dragging
}
var _drag_state = DragState.None

func _on_init():
	var saved_game = null
	assert(not not server)
	
	_status.text = ""
	
	_back_button.hide()
	
	_tabs.show_named("title")
	
	if not saved_game:
		_hide_group("only_if_saved")
	
	_hide_group("only_if_playing")
	

func _hide_group(group_name: String):
	for n in get_tree().get_nodes_in_group(group_name):
		n.hide()
	
func _start():
	if _room_parent.get_child_count() > 0 :
		#_log("Room place is not empty! Clearing it.")
		make_empty(_room_parent)
	
	# TODO "open" word is confusing
	_side_menu.open()
	
	_side_menu.fixed = false
	_side_menu.end_enabled = true
	
	_text.text = ""

	_curtain.play("closed")
	
	
	# TODO wait until menu is fully closed
	
	var ret = game_instance.start_game_request(_room_parent)

	if not ret:
		_log_error("Couldn't start game")
		_end_game()
	# else signal game_started was just received (or it will now)

	#_item_menu.hide()
	#warning-ignore:return_value_discarded
	#self.connect("item_selected", _item_menu, "_on_item_selected")
	#warning-ignore:return_value_discarded
	#self.connect("item_deselected", _item_menu, "_on_item_deselected")
	#_item_menu.init(self, data)

func _on_start():
	_log_warning("TODO game started")
	pass
	
func _on_end():
	_log_warning("TODO game ended")
	pass

####


#	@SERVER EVENTS

func _on_server_input_enabled():
	_log_warning("TODO implement _on_server_input_enabled")
	
func _on_server_input_disabled():
	_log_warning("TODO implement _on_server_input_disabled")

func _on_server_room_loaded(_room):
	_log_warning("TODO implement _on_server_room_loaded")

func _on_item_enabled(_item):
	_log_warning("TODO implement _on_item_enabled")

func _on_item_disabled(item):
	if _current_item == item:
		_select_item(null)
	

func _on_server_wait_started(_duration: float, _skippable: bool):
	_log_warning("TODO implement _on_server_wait_started")

func _on_server_wait_ended():
	_text.text = ""
	_log_warning("TODO implement _on_server_wait_ended")

func _on_server_say(subject: Node, speech: String, _duration: float, _skippable: bool):
	var color = subject.color if subject else server.options.default_color
	
	_text.text = speech
	_text.modulate = color

func _on_server_item_added(item: Node):
	_inventory.add_item(item)

func _on_server_item_removed(item: Node):
	_inventory.remove_item(item)
	
	if _current_item == item:
		_select_item(null)

func _on_server_tool_set(_new_tool, _verb_name: String):
	pass

func _on_server_curtain_up():
	_curtain.play("up")
	
func _on_server_curtain_down():
	_curtain.play("down")

###

func _select_inventory_item(inventory_item):
	var view = inventory_item
	var model = inventory_item.model
	
	var rect: Rect2 = view.get_global_rect()
	var menu_position: Vector2 = rect.position + rect.size / 2
	_select_item(model, menu_position)
	
	
func _select_item(_new_item, position = Vector2(960, 540)): #is_inventory = false):
	if _current_item == _new_item:
		return
	
	if _current_item:
		emit_signal("item_deselected", _current_item)
		#_current_item.modulate = Color.white
	
	_current_item = _new_item
	if _new_item:
		emit_signal("item_selected", _new_item, position)
		
#s		_new_item.modulate = Color(0.7, 1 ,0.7)
		

func _on_close_menu_button_pressed():
	_select_item(null)

####

### Clicking ui events

func _on_ui_click(position: Vector2):
	#if _inventory_visible:
	#	_hide_inventory()
	
	if not game_instance:
		return
	
	if _current_item != null:
		_select_item(null)
		return
	
	var world_position = position
	
	var item = _get_scene_item_at(world_position)
	if item:
		game_instance.interact_request(item, server.game_script.default_action)
		#if _inventory_visible:
		#	_hide_inventory()
	
	else:
		var inventory_item = _get_inventory_item_at(world_position)
		
		if inventory_item != null:
			_select_inventory_item(inventory_item)
		else:
			#if _inventory_visible:
			#	_hide_inventory()
			if game_instance.is_navigable(world_position):
				#$cursor.position = world_position
				#$cursor/animation.play("default")
				#$cursor/animation.play("go")
				game_instance.go_to_request(world_position)
	
func _on_ui_start_hold(position: Vector2):
	#if _inventory_visible:
	#	_hide_inventory()
	
	var item = _get_scene_item_at(position)
	
	if item:
		_select_item(item, item.position)
	else:
		var inventory_item = _get_inventory_item_at(position)
		
		if inventory_item != null:
			_select_inventory_item(inventory_item)
		else:
			_select_item(null)

func _on_ui_lock_hold():
	pass
	
func _on_ui_end_hold():
	_log("_on_ui_end_hold")
	
func _on_ui_start_drag(position: Vector2):
	if _drag_state != DragState.None:
		_log_warning("Unexpected drag state '%s'" % DragState.keys()[_drag_state])
		return
	
	_initial_drag_position = position
	_drag_state = DragState.Dragging

func _on_ui_drag(position: Vector2):
	if _drag_state != DragState.Dragging:
		return
	
	#_update_tool_position(position)
	
	var delta = position - _initial_drag_position
	
	if abs(delta.x) > abs(delta.y):
		delta.y = 0
		_initial_drag_position.y = position.y
	else:
		delta.x = 0
		_initial_drag_position.x = position.x
	
	# TODO fix inventory
	
#	var menu_is_open = _side_menu.slide(delta)
#	if menu_is_open and _inventory_base._moving:
#		_inventory_base.drop()
#
#	if not menu_is_open:
#		_inventory_base.slide(delta)

	var _m1 = _side_menu.slide(delta)
	var _m2 = _inventory_base.slide(delta)
	
func _on_ui_end_drag(_position: Vector2):
	if _drag_state != DragState.Dragging:
		return
	
	_side_menu.drop()
	_inventory_base.drop()
	
	_drag_state = DragState.None

#func _on_item_menu_item_action(_bad_item, new_action):
#	var item = _current_item
#	var action_name = new_action.target
#
#	_select_item(null)
#
#	game_instance.interact_request(item, action_name)

func _get_inventory_item_at(position: Vector2):
	var ret = _inventory.get_item_at(position)
	
	return ret

func _on_inventory_button_pressed():
	pass#_inventory_base.toggle()


func _on_continue_pressed():
	pass # Replace with function body.

func _on_save_game_pressed():
	pass # Replace with function body.

func _on_continue_previous_pressed():
	pass # Replace with function body.

func _on_new_game_pressed():
	if game_instance:
		_log_warning("Replay not implemented!")
		return
	
	_start_game()
	
	_start()
	

func _on_load_game_pressed():
	if _pressed_button == _load_button:
		return
	
	_close_all()
	
	_load_button.set_pressed(true)
	_pressed_button = _load_button
	
	_back_button.show()
	_status.text = "loading..."
	_game_list.init(server)
	_game_list.show()
	_status.text = ""
	_tabs.show_named("game_list")

func _on_options_pressed():
	#if _pressed_button == _options_button:
	#	return
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
