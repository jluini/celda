extends Node

class_name AudioPlayerPool

signal player_finished

var _players = {}

func remove_player(key: String):
	if not has_player(key):
		print("No player '%s'" % key)
		return
	
	var player = _players[key]
	remove_child(player)
	
	player.queue_free()
	
	_players.erase(key)
	
func new_player(key: String, stream: AudioStream) -> AudioStreamPlayer:
	if has_player(key):
		print("Already has a player '%s'" % key)
		return get_player(key)
	
	var ret: AudioStreamPlayer = LoopinStreamPlayer.new(key)
	
	ret.set_stream(stream)
	
	var _r = ret.connect("finished", self, "_on_player_finished", [key])
	add_child(ret)
	
	_players[key] = ret
	
	return ret

func has_player(key: String) -> bool:
	return _players.has(key)

func get_player(key: String) -> AudioStreamPlayer:
	if not has_player(key):
		print("No player '%s'!" % key)
		return null
	
	return _players[key]

func _on_player_finished(key: String):
	emit_signal("player_finished", key)
