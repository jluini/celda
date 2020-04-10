extends "res://tools/grog/base_client.gd"

signal item_selected # (item)
signal item_deselected # (item)


export (NodePath) var _room_parent_path


onready var _room_parent = get_node(_room_parent_path)

onready var _curtain = $curtain
onready var _item_menu = $ui/item_menu


onready var _text: Label = $ui/text

var _current_item = null

func _on_init():
	if _room_parent.get_child_count() > 0 :
		print("Room place is not empty! Clearing it.")
		make_empty(_room_parent)
	
	var ret = server.start_game_request(_room_parent)
	
	if not ret:
		print("Couldn't start game")
		_end_game()
	# else signal game_started was just received (or it will now)
	
	_text.text = ""
	
	_curtain.play("closed")
	_item_menu.hide()
	
	#warning-ignore:return_value_discarded
	self.connect("item_selected", _item_menu, "_on_item_selected")
	self.connect("item_deselected", _item_menu, "_on_item_deselected")
	
	_item_menu.init(self, data)
	
func _on_start():
	pass
	
func _on_end():
	pass

####


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
	_text.text = ""
	pass # print("_on_server_wait_ended")

func _on_server_say(subject: Node, speech: String, _duration: float, skippable: bool):
	var color = subject.color if subject else server.options.default_color
	
	_text.text = speech
	_text.modulate = color

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

###

func _select_item(_new_item):
	if _current_item == _new_item:
		return
	
	if _current_item:
		emit_signal("item_deselected", _current_item)
		#_current_item.modulate = Color.white
	
	_current_item = _new_item
	if _new_item:
		emit_signal("item_selected", _new_item)
		
#		_new_item.modulate = Color(0.7, 1 ,0.7)
		

func _on_close_menu_button_pressed():
	_select_item(null)

####

func _on_skip_button_pressed():
	print("TODO: skip")
	pass # Replace with function body.

### Clicking ui events

func _on_ui_click(position: Vector2):
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
	
func _on_ui_start_hold(position: Vector2):
	var item = _get_scene_item_at(position)
	
	if item:
		_select_item(item)
	else:
		_select_item(null)

func _on_ui_lock_hold():
	pass # print("_on_ui_lock_hold")
func _on_ui_end_hold():
	print("_on_ui_end_hold")
func _on_ui_start_drag(position: Vector2):
	print("_on_ui_start_drag")
func _on_ui_drag(position: Vector2):
	print("_on_ui_drag")
func _on_ui_end_drag(position: Vector2):
	print("_on_ui_end_drag")


func _on_item_menu_item_action(_bad_item, new_action):
#	print("_on_item_menu_item_action(%s, %s)" % [item, action])
#	
#func _on_action_selected(_old_action, new_action: Node):
	var item = _current_item
	var action_name = new_action.target
	
	_select_item(null)
	
	server.interact_request(item, action_name)
