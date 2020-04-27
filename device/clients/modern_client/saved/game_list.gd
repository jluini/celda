extends Control

export (PackedScene) var entry_model

func _ready():
	pass

func init(environment):
	while get_child_count() > 1:
		print("Removing")
		var c = get_child(1)
		remove_child(c)
		c.queue_free()
	
	var saved_games = environment.get_saved_games()
	
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
	var new_entry = entry_model.instance()
	
	new_entry.set_target(saved_game)
	
	add_child(new_entry)
	
	return new_entry
