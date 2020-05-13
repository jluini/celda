extends "res://tools/modular/module.gd"

export (String) var saved_games_path = "user://saved_games"

export (Resource) var game_script

onready var compiler = $compiler

var _compiled_game = null

var game_instance: Node = null

func _get_module_name():
	return "grog-server"

func _on_initialize() -> Dictionary:
	if not game_script:
		return { valid = false, message = "there's no game set" }
	
	var res = game_script.prepare(compiler)
	
	if not res.valid:
		# invalid game
		return res
	
	var dir = Directory.new()
	
	var user_dir_result = dir.open("user://")
	
	if user_dir_result != OK:
		return { valid = false, message = "can't create files" }
	
	if not dir.dir_exists(saved_games_path):
		_log("folder 'saved_games' does not exist; creating it")
		dir.make_dir(saved_games_path)
	
	return { valid = true }

func get_signals() -> Array:
	return []

func get_game_script():
	if not game_script:
		_log("there's no game set")
	return game_script

func new_game():
	if not game_script:
		_log("there's no game set")
		return
	
	assert(not game_instance)
	
	game_instance = load("res://tools/grog/core/game_instance.gd").new()
	
	var ok = game_instance.init(self, game_script)
	
	if not ok:
		_log("deleting game instance")
		game_instance.queue_free()
		return null
	
	add_child(game_instance)
	
	return game_instance

func get_saved_games():
	var ret = []
	var dir = Directory.new()
		
	var saved_games_result = dir.open(saved_games_path)
	if saved_games_result != OK:
		return { valid = false, message = "can't open folder '%s'" % saved_games_path }
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			# TODO check file
			
			var name = file_name
			
			ret.append({
				filename = file_name,
				name = name
			})
		else:
			pass # Ignoring dir
			
		file_name = dir.get_next()
	
	return ret


func _on_list_saved_games_pressed():
	_modular.make_empty($control/saved_games)
	
	var sgs = get_saved_games()
	for sg in sgs:
		var new_label = Label.new()
		new_label.text = sg.filename
		$control/saved_games.add_child(new_label)


func _on_generate_fake_pressed():
	var file = File.new()
	file.open(saved_games_path + "/fake.grog", File.WRITE)
	file.store_string("content")
	file.close()


