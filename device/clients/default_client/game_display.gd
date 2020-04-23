extends "res://tools/grog/base/base_client.gd"

export (float) var distance_threshold = 50

export (Resource) var action_button_model

export (NodePath) var curtain_path

export (NodePath) var room_area_path
export (NodePath) var room_place_path

export (NodePath) var inventory_path
export (NodePath) var controls_place_path

export (NodePath) var actions_path
export (NodePath) var action_display_path

export (NodePath) var text_label_path
export (NodePath) var text_label_anchor_path

# debug flags
export (NodePath) var input_enabled_flag_path
export (NodePath) var skippable_flag_path

# Server

var _skippable: bool
var _input_enabled: bool

# Input
enum InputState { Nothing, DoingLeftClick }
var input_state = InputState.Nothing
var input_position: Vector2

var current_action = null
var default_action: Node

var current_item = null # Node for scene_item or Resource for inventory_item
var current_tool = null # Node for scene_item or Resource for inventory_item
var current_tool_verb = ""

# Node hooks
onready var _curtain: AnimationPlayer = get_node(curtain_path)

onready var _room_area: Control = get_node(room_area_path)
onready var _room_place: Control = get_node(room_place_path)

onready var _controls_place: Control = get_node(controls_place_path)
onready var _inventory: Control = get_node(inventory_path)

onready var _actions: Control = get_node(actions_path)
onready var _action_display: Control = get_node(action_display_path)

onready var _text_label: RichTextLabel = get_node(text_label_path)
onready var _text_label_anchor: Control = get_node(text_label_anchor_path)

onready var _default_text_position: Vector2 = _text_label_anchor.rect_position

onready var _input_enabled_flag: CheckButton = get_node(input_enabled_flag_path)
onready var _skippable_flag: CheckButton = get_node(skippable_flag_path)

func _ready():
	#warning-ignore:return_value_discarded
	_actions.connect("on_element_selected", self, "_on_action_selected")
	#warning-ignore:return_value_discarded
	_actions.connect("on_element_deselected", self, "_on_action_deselected")

func _on_init():
	default_action = _actions.element_view_model.instance()
	default_action.set_target(0, data.default_action)
		
	_hide_controls()
	
	_inventory.clear()
	
	make_empty(_actions)
	
	for action_name in data.actions:
		_actions.add_element(action_name)
	
	_clear_all()
	
	if not server.start_game_request(_room_place):
		_end_game()
	
	# else signal game_started was just received (or it will now)

func _on_start():
	_hide_all()
	_set_current_action(default_action)

func _on_end():
	_clear_all()
	_hide_all()
	default_action.queue_free()
	_curtain.play("default")

func _input(event):
	if not server or not server.is_playing():
		return
	
	if event is InputEventMouseButton:
		var mouse_position: Vector2 = event.position
			
		if event.button_index == BUTTON_LEFT and server.current_room:
			if event.pressed:
				if input_state == InputState.Nothing:
					input_state = InputState.DoingLeftClick
					input_position = mouse_position
			else:
				if input_state == InputState.DoingLeftClick:
					var dist = mouse_position.distance_to(input_position)
					if dist < distance_threshold:
						_left_click(input_position)
					
					input_state = InputState.Nothing
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				if not server.skip_or_cancel_request():
					_clear_all()
					
				
	elif event is InputEventMouseMotion:
		if not server.current_room:
			return
		
		var mouse_position: Vector2 = event.position
		
		var item = _get_item_at(mouse_position)
		
		if item != current_item:
			_set_current_item(item)
	
	elif event is InputEventKey:
		if not event.pressed:
			return
		
		if event.is_action_pressed("grog_toggle_fullscreen"):
			_toggle_fullscreen()
		if event.scancode == KEY_Q:
			_actions.select(0)
		elif event.scancode == KEY_W:
			_actions.select(1)
		elif event.scancode == KEY_E:
			_actions.select(2)
		elif event.scancode == KEY_A:
			_actions.select(3)
		elif event.scancode == KEY_S:
			_actions.select(4)
		elif event.scancode == KEY_D:
			_actions.select(5)
	else:
		print("Ignoring event %s" % event)
		
#	@SERVER EVENTS

func _on_server_input_enabled():
	_set_input_enabled(true)
	_show_controls()
	
func _on_server_input_disabled():
	_set_input_enabled(false)
	_hide_controls()

func _on_server_room_loaded(_room):
	_curtain.play("default")
	pass

func _on_item_enabled(_item):
	pass

func _on_item_disabled(item):
	if current_item == item:
		_set_current_item(null)
	elif current_tool == item:
		current_item = null
		current_tool = null
		current_tool_verb = ""
		_update_action_display()

func _on_server_wait_started(_duration: float, skippable: bool):
	# start waiting '_duration' seconds
	_set_skippable(skippable)

func _on_server_wait_ended():
	_text_label.clear() # do always?
	if _skippable:
		_set_skippable(false)

func _on_server_say(subject: Node, speech: String, _duration: float, skippable: bool):
	# start waiting '_duration' seconds
	
	if subject:
		var position = subject.get_speech_position() + _room_place.rect_position
		_say_text(speech, subject.color, position)
	else:
		_say_text(speech, server.options.default_color, _default_text_position)
	
	_set_skippable(skippable)

func _on_server_item_added(item):
	_inventory.add_item(item)

func _on_server_item_removed(item: Node):
	_inventory.remove_item(item)
	
	if current_item == item:
		_set_current_item(null)
	elif current_tool == item:
		current_item = null
		current_tool = null
		current_tool_verb = ""
		_update_action_display()
	
func _on_server_tool_set(new_tool, verb_name: String):
	current_tool = new_tool
	current_tool_verb = verb_name
	current_item = null
	_update_action_display()

func _on_server_curtain_up():
	_curtain.play("up")
	
func _on_server_curtain_down():
	_curtain.play("down")

#	@PRIVATE


func _hide_all():
	_set_skippable(false)
	_set_input_enabled(false)
	_text_label.clear()
	_hide_controls()
	#_action_display.text = ""

func _left_click(position: Vector2):
	var clicked_item = _get_item_at(position)
	
	if clicked_item:
		if current_tool:
			#server.use_tool_request(clicked_item)
			server.interact_request(clicked_item, current_tool_verb, current_tool)
		else:
			server.interact_request(clicked_item, current_action.target)
		
		_clear_all()
	elif _is_in_room_area(position) and not current_tool:
		var world_pos = _global_to_world(position)
		server.go_to_request(world_pos)

func _get_item_at(position: Vector2):
	# check loaded scene items
	for item in _loaded_items:
		# ignore current tool for now
		if item == current_tool:
			continue
		
		var world_pos = _global_to_world(position)
		var item_center = item.position + item.offset
		
		var disp: Vector2 = item_center - world_pos
		var distance = disp.length()
		
		if distance <= item.radius:
			return item
	
	# then check inventory items
	return _inventory.get_item_at(position)

func _say_text(speech, color, text_position):
	_text_label_anchor.rect_position = text_position
	
	_text_label.clear()
	_text_label.push_color(color)
	_text_label.push_align(RichTextLabel.ALIGN_CENTER)
	_text_label.add_text(speech)
	_text_label.pop()
	_text_label.pop()
	
func _show_controls():
	if _controls_place:
		_controls_place.show()

func _hide_controls():
	if _controls_place:
		_controls_place.hide()

func _on_quit_button_pressed():
	if server:
		server.stop_request()

func _on_save_button_pressed():
	if server:
		pass #server.save_request()

func _on_load_button_pressed():
	if server:
		pass


#	@DEBUG FLAGS

func _set_skippable(new_value: bool):
	_skippable = new_value
	_skippable_flag.pressed = new_value

func _set_input_enabled(new_value: bool):
	_input_enabled = new_value
	_input_enabled_flag.pressed = new_value

func _on_action_selected(_old_action, new_action: Node):
	current_tool = null
	current_tool_verb = ""
	_set_current_action(new_action)
	

func _on_action_deselected(_old_view):
	current_tool = null
	current_tool_verb = ""
	_set_current_action(default_action)

func _set_current_action(new_action):
	current_action = new_action
	_update_action_display()
	
func _set_current_item(new_item):
	current_item = new_item
	_update_action_display()

func _update_action_display():
	if current_tool:
		var prev_tool_translation_key = "TOOL_PREV_" + current_tool_verb.to_upper()
		var post_tool_translation_key = "TOOL_POST_" + current_tool_verb.to_upper()
		var localized_prev = capitalize_first(tr(prev_tool_translation_key))
		var localized_post = tr(post_tool_translation_key)
		var localized_tool = _item_name(current_tool)
		
		var item_tail = ""
		if current_item:
			var localized_item = _item_name(current_item)
			item_tail = " " + localized_item
		
		_action_display.text = localized_prev + " " + localized_tool + " " + localized_post + item_tail
	else:
		if current_item:
			var localized_item = _item_name(current_item)
			_action_display.text = current_action.localized_name + " " + localized_item
		else:
			_action_display.text = current_action.localized_name

# Misc

func _item_name(item):
	var translation_key = "ITEM_" + item.get_key().to_upper()
	return tr(translation_key)

func _clear_all():
	current_item = null
	current_tool = null
	current_tool_verb = ""
	_actions.deselect()
	current_action = default_action
	_update_action_display()
	
func _on_fullscreen_button_pressed():
	_toggle_fullscreen()

func _toggle_fullscreen():
	OS.window_fullscreen = !OS.window_fullscreen

func _global_to_world(position: Vector2, difference = true):
	var scale = 0.787
	
	var viewport_rect = _room_place.rect_global_position
	var pos2 = (position - viewport_rect) if difference else position
	var world_pos = pos2 / scale
	
	return world_pos

func _is_in_room_area(position: Vector2):
	var w = _global_to_world(position)
	return w.x >= 0 and w.x <= 1920 and w.y >= 0 and w.y <= 1080
	
