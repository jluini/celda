extends "res://tools/grog/base_client.gd"

signal item_selected # (item)
signal item_deselected # (item)

export (NodePath) var _room_parent_path

onready var _room_parent = get_node(_room_parent_path)

onready var _curtain = $ui/curtain_animation
onready var _item_menu = $ui/item_menu
onready var _inventory = $ui/inventory_base/inventory

onready var _text: Label = $ui/text

onready var _tool: Control = $ui/tool

var _inventory_visible = false
var _hidden_inventory_pos: Vector2
var _visible_inventory_pos: Vector2

var _current_item = null

var _tool_item = null
var _tool_verb 
var _initial_drag_position: Vector2

enum DragState {
	None,
	Trying,
	Dragging
}
var _drag_state = DragState.None


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
	#warning-ignore:return_value_discarded
	self.connect("item_deselected", _item_menu, "_on_item_deselected")
	
	_item_menu.init(self, data)
	
	#$ui/inventory_animation.play("hidden")
	_hidden_inventory_pos = $ui/inventory_base.rect_position
	_visible_inventory_pos = _hidden_inventory_pos
	_visible_inventory_pos.y -= 200
	
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

func _on_item_enabled(_item):
	pass

func _on_item_disabled(item):
	if _current_item == item:
		_select_item(null)
	

func _on_server_wait_started(_duration: float, _skippable: bool):
	pass # print("_on_server_wait_started")

func _on_server_wait_ended():
	_text.text = ""
	pass # print("_on_server_wait_ended")

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

func _on_server_tool_set(new_tool, verb_name: String):
	if _drag_state != DragState.Trying:
		print("Unexpected tool_set")
		return
	
	if _tool_item.model != new_tool:
		print("Expecting to use another tool!")
		_drag_state = DragState.None
		return
	
	_tool_verb = verb_name
	
	_drag_state = DragState.Dragging
	_tool.texture = _tool_item.model.texture
	_tool.show()
	_update_tool_position(_initial_drag_position)
	

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
		
#		_new_item.modulate = Color(0.7, 1 ,0.7)
		

func _on_close_menu_button_pressed():
	_select_item(null)

####

func _on_skip_button_pressed():
	print("TODO: skip")
	pass # Replace with function body.

### Clicking ui events

func _on_ui_click(position: Vector2):
	#if _inventory_visible:
	#	_hide_inventory()
	
	if _current_item != null:
		_select_item(null)
		return
	
	var world_position = position
	
	var item = _get_scene_item_at(world_position)
	if item:
		server.interact_request(item, data.default_action)
		if _inventory_visible:
			_hide_inventory()
	
	else:
		var inventory_item = _get_inventory_item_at(world_position)
		
		if inventory_item != null:
			_select_inventory_item(inventory_item)
		else:
			if _inventory_visible:
				_hide_inventory()
			if server.is_navigable(world_position):
				$cursor.position = world_position
				$cursor/animation.play("default")
				$cursor/animation.play("go")
				server.go_to_request(world_position)
	
func _on_ui_start_hold(position: Vector2):
	if _inventory_visible:
		_hide_inventory()
	
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
	pass # print("_on_ui_lock_hold")
func _on_ui_end_hold():
	print("_on_ui_end_hold")
	
func _on_ui_start_drag(position: Vector2):
	if _drag_state != DragState.None:
		print("Unexpected drag state '%s'" % DragState.keys()[_drag_state])
		return
	
	#_drag_starting_position = position
	_initial_drag_position = position
	_drag_state = DragState.Dragging
	
#	var item = _get_inventory_item_at(position)
#
#	if not item:
#		return
#
#	var model = item.model
#	if not model.has_action("use"):
#		return
#
#	_drag_state = DragState.Trying
#	_tool_item = item
#	_initial_drag_position = position
#	server.interact_request(item.model, "use")

func _on_ui_drag(position: Vector2):
	if _drag_state != DragState.Dragging:
		return
	
	#_update_tool_position(position)
	
	var delta = position - _initial_drag_position
	var dy = delta.y
	
	if _inventory_visible:
		dy = max(0, dy)
		if dy > 100:
			_hide_inventory()
			_drag_state = DragState.None
		else:
			$ui/inventory_base.rect_position.y = _visible_inventory_pos.y + dy
	else:
		dy = min(0, dy)
		if dy < -100:
			_show_inventory()
			_drag_state = DragState.None
		else:
			$ui/inventory_base.rect_position.y = _hidden_inventory_pos.y + dy
	

func _on_ui_end_drag(position: Vector2):
	if _drag_state == DragState.Trying:
		# Cancels use attempt
		_drag_state = DragState.None
		return
	elif _drag_state != DragState.Dragging:
		return
	
	if _inventory_visible:
		_show_inventory()
	else:
		_hide_inventory()
	
	_drag_state = DragState.None
	
	
#	_tool.hide()
#	_drag_state = DragState.None
#
#	var target_item = _get_scene_item_at(position)
#
#	if not target_item:
#		return
#
#	server.interact_request(target_item, _tool_verb, _tool_item.model)
#	_tool_item = null
#

func _on_ui_screen_drag(_delta: Vector2):
	pass
#	var dy = delta.y
#
#	if _inventory_visible:
#		dy = max(0, dy)
#		if dy > 60:
#			_hide_inventory()
#		else:
#			$ui/inventory_base.rect_position.y = _visible_inventory_pos.y + dy
#	else:
#		dy = min(0, dy)
#		if dy < -60:
#			_show_inventory()
#		else:
#			$ui/inventory_base.rect_position.y = _hidden_inventory_pos.y + dy


func _on_item_menu_item_action(_bad_item, new_action):
	var item = _current_item
	var action_name = new_action.target
	
	_select_item(null)
	
	server.interact_request(item, action_name)

func _get_inventory_item_at(position: Vector2):
	var ret = _inventory.get_item_at(position)
	
	return ret

func _update_tool_position(position: Vector2):
	_tool.set_position(position - _tool.get_rect().size / 2)


func _show_inventory():
	_interpolate_inventory_position(_hidden_inventory_pos, _visible_inventory_pos)
	_interpolate_button_visibility(Color.transparent)
	_inventory_visible = true

func _hide_inventory():
	_interpolate_inventory_position(_visible_inventory_pos, _hidden_inventory_pos)
	_interpolate_button_visibility(Color.white)
	_inventory_visible = false

func _on_inventory_button_pressed():
	if not _inventory_visible:
		_show_inventory()
	else:
		_hide_inventory()

func _interpolate_inventory_position(_initial: Vector2, final: Vector2):
	var tween = $ui/inventory_base/tween
	tween.interpolate_property(
		$ui/inventory_base,
		"rect_position",
		null, # initial,
		final,
		0.3,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)
	tween.start()


func _interpolate_button_visibility(final: Color):
	var tween = $ui/inventory_base/tween2
	
	tween.interpolate_property(
		$ui/inventory_button,
		"modulate",
		null, # initial,
		final,
		0.3,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)
	tween.start()

