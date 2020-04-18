extends Node

signal music_changed

signal game_ended

var server
var data

var _loaded_items = []

func init(p_game_server):
	server = p_game_server
	data = server.data
	
	server.connect("game_server_event", self, "on_server_event")
	
	_on_init()
	
func _end_game():
	_on_end()
	server = null
	emit_signal("game_ended")
	
####

func on_server_event(event_name, args):
	var handler_name = "_on_server_" + event_name
	
	if self.has_method(handler_name):
		self.callv(handler_name, args)
	else:
		print("Implemente method '%s'" % handler_name)

#	@SERVER EVENTS

func _on_server_game_started(_player):
	# TODO register player as an "item"?
	_on_start()

func _on_server_game_ended():
	_end_game()

func _on_server_input_enabled():
	print("Override _on_server_input_enabled()")
	
func _on_server_input_disabled():
	print("Override _on_server_input_disabled()")

func _on_server_room_loaded(_room):
	print("Override _on_server_room_loaded()")

func _on_server_item_enabled(item):
	_loaded_items.append(item)
	_on_item_enabled(item)

func _on_server_item_disabled(item):
	_loaded_items.erase(item)
	_on_item_disabled(item)

func _on_server_wait_started(_duration: float, _skippable: bool):
	print("Override _on_server_wait_started()")

func _on_server_wait_ended():
	print("Override _on_server_wait_ended()")

func _on_server_say(_subject: Node, _speech: String, _duration: float, _skippable: bool):
	print("Override _on_server_say()")

func _on_server_item_added(_item):
	print("Override _on_server_item_added()")

func _on_server_item_removed(_item: Node):
	print("Override _on_server_item_removed()")
	
func _on_server_tool_set(_new_tool, _verb_name: String):
	print("Override _on_server_tool_set()")

func _on_server_curtain_up():
	print("Override _on_server_curtain_up()")
	
func _on_server_curtain_down():
	print("Override _on_server_curtain_down()")
	

func _get_scene_item_at(position: Vector2):
	for item in _loaded_items:
		var world_pos = position # _global_to_world(position)
		var item_center = item.position + item.offset
		
		var disp: Vector2 = item_center - world_pos
		var distance = disp.length()
		
		if distance <= item.radius:
			return item
	
	return null

### Misc

func _item_name(item):
	var translation_key = "ITEM_" + item.get_key().to_upper()
	return tr(translation_key)

func make_empty(node: Node):
	while node.get_child_count() > 0:
		var child = node.get_child(0)
		node.remove_child(child)
		child.queue_free()

func capitalize_first(text: String) -> String:
	text[0] = text[0].to_upper()
	return text

###

func _on_init():
	print("Override _on_init()")
	
func _on_start():
	print("Override _on_start()")
	
func _on_end():
	print("Override _on_end()")

func _on_item_enabled(_item):
	print("Override _on_item_enabled()")

func _on_item_disabled(_item):
	print("Override _on_item_disabled()")
