extends Control

export (PackedScene) var entry_model

var _client: Node

func _ready():
	pass

func init(client, saved_games: Array):
	_client = client
	
	while get_child_count() > 1:
		var c = get_child(1)
		remove_child(c)
		c.queue_free()
	
	if saved_games:
		get_child(0).hide()
		for sg in saved_games:
			add_entry(sg)
	else:
		get_child(0).show()

func add_entry(saved_game):
	if not entry_model:
		print("No model")
		return null
	var new_entry: Node = entry_model.instance()
	
	new_entry.set_target(saved_game)
	
	# warning-ignore:return_value_discarded
	new_entry.connect("load_game_requested", _client, "on_load_game_requested")
	
	add_child(new_entry)
	
	return new_entry
