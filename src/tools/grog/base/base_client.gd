extends "res://tools/modular/module.gd"

signal game_ended

export (Dictionary) var named_sounds = {}

onready var _audio_player = $audio_player

var server
var game_instance = null

var _loaded_items: Array

var _sound_signal_prefix := "sound/"

func _get_module_name():
	return "grog-client"

func _on_initialize() -> Dictionary:
	server = _modular.get_module("grog-server")
	if not server:
		return { valid = false, message = "'grog-server' is required"}
	
	_on_init()
	
	return { valid = true }

func get_signals() -> Array:
	return []
	
func _end_game():
	_on_end()
	
	emit_signal("game_ended")
	
####

func on_server_event(event_name, args):
	var handler_name = "_on_server_" + event_name
	
	if self.has_method(handler_name):
		self.callv(handler_name, args)
	else:
		_log_warning("implement method '%s'" % handler_name)

#	@SERVER EVENTS

func _on_server_game_started(_player):
	# TODO register player as an "item"?
	_on_start()

func _on_server_game_ended():
	_end_game()

func _on_server_room_loaded(_room):
	_log_warning("override _on_server_room_loaded()")

func _on_server_item_enabled(item):
	_loaded_items.append(item)
	_on_item_enabled(item)

func _on_server_item_disabled(item):
	_loaded_items.erase(item)
	_on_item_disabled(item)

func _on_server_say(_subject: Node, _speech: String, _duration: float, _skippable: bool):
	_log_warning("override _on_server_say()")

func _on_server_item_added(_item: Object):
	_log_warning("override _on_server_item_added()")

func _on_server_item_removed(_item: Object):
	_log_warning("override _on_server_item_removed()")
	
func _on_server_curtain_up():
	_log_warning("override _on_server_curtain_up()")
	
func _on_server_curtain_down():
	_log_warning("override _on_server_curtain_down()")

func _on_server_variable_set(var_name: String, new_value):
	if var_name == "music":
		if new_value:
			_modular.broadcast("music", "start", [new_value])
		else:
			_modular.broadcast("music", "stop", [])

func _on_server_tool_set(_item, _verb: String):
	_log_warning("override _on_server_tool_set")

func _on_server_signal_emitted(signal_name: String):
	if signal_name.begins_with(_sound_signal_prefix):
		var sound_name: String = signal_name.substr(_sound_signal_prefix.length())
		
		var sound: AudioStream = named_sounds.get(sound_name, null)
		if sound:
			# TODO check not looped?
			_play_sound(sound)
		else:
			_log_warning("sound '%s' not found" % sound_name)
	else:
		_log_warning("ignoring signal '%s'" % signal_name)
###

func _get_scene_item_at(position: Vector2):
	for item in _loaded_items:
		var item_rect : Rect2 = item.get_item_rect()
		
		if item_rect.has_point(position):
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
	_log_warning("override _on_init()")
	
func _on_start():
	_log_warning("override _on_start()")
	
func _on_end():
	_log_warning("override _on_end()")

func _on_item_enabled(_item):
	_log_warning("override _on_item_enabled()")

func _on_item_disabled(_item):
	_log_warning("override _on_item_disabled()")


func _start_game_from(filename: String) -> Dictionary:
	if game_instance:
		_log_debug("deleting old game")
		var delete_game_result: Dictionary = server.delete_game()

		if not delete_game_result.valid:
			_log_debug("couldn't delete old game")
			return delete_game_result
		
		game_instance = null
	
	_loaded_items = []
	
	var new_game_result: Dictionary = server.new_game_from(filename)
	
	if new_game_result.valid:
		game_instance = new_game_result.game_instance
		game_instance.connect("game_event", self, "on_server_event")
	
	return new_game_result

func _play_sound(sound_stream: AudioStream):
	_audio_player.stream = sound_stream
	_audio_player.play()
