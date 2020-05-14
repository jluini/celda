extends "res://tools/modular/module.gd"

export (String) var root_path = "user://"
export (String) var saved_games_path = "saved_games"
export (String) var quick_save_path = "quicksave.tres"

export (Resource) var game_script

onready var compiler = $compiler

var _compiled_game = null

var game_instance: Node = null

func _get_module_name():
	return "grog-server"

func _get_abbreviated_name():
	return "gs"

func _on_initialize() -> Dictionary:
	if not game_script:
		return { valid = false, message = "there's no game set" }
	
	var res = game_script.prepare(compiler)
	
	if not res.valid:
		# invalid game
		return res
	
	var _save_folder_result: Dictionary = _get_or_create_save_folder()
	
	if _save_folder_result.valid:
		_log_debug("save folder successfully opened")
	else:
		_log_warning("save folder couldn't be opened")
	
	return { valid = true }

func get_signals() -> Array:
	return []

func get_game_script():
	if not game_script:
		_log_warning("there's no game set")
	return game_script

func new_game():
	if not game_script:
		_log_warning("there's no game set")
		return
	
	assert(not game_instance)
	
	game_instance = load("res://tools/grog/core/game_instance.gd").new()
	game_instance.name = "game_instance"
	
	# make game pausable
	game_instance.pause_mode = PAUSE_MODE_STOP
	
	var ok = game_instance.init(self, game_script)
	
	if not ok:
		_log_debug("deleting game instance")
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

# tries to save current game instance in default file
func save_game() -> Dictionary:
	if not game_instance:
		var message = "can't save: no game" 
		_log_warning(message)
		return { valid = false, message = message }
	
	if not game_instance.is_paused():
		var message = "can't save: game is not paused"
		_log_warning(message)
		return { valid = false, message = message }
	
	var save_folder_result: Dictionary = _get_or_create_save_folder()
	
	if not save_folder_result.valid:
		return save_folder_result
	
	return _save_game_in(quick_save_path)

func _save_game_in(path: String):
	var full_path := "%s%s/%s" % [root_path, saved_games_path, path]
	
	_log_debug("trying to save game in '%s'" % full_path)
	
	var saved_game := SavedGame.new()
	saved_game.read_from(game_instance)
	var save_result = ResourceSaver.save(full_path, saved_game, ResourceSaver.FLAG_CHANGE_PATH)
	
	if save_result != OK:
		var message = "couldn't save to '%s' (error %s)" % [full_path, save_result]
		_log_error(message)
		return { valid = false, message = message }
	
	return { valid = true }

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

func _get_or_create_save_folder() -> Dictionary:
	var dir := Directory.new()
	
	var user_dir_result = dir.open(root_path)
	
	if user_dir_result != OK:
		var message = "can't open user dir"
		_log_error(message)
		return { valid = false, message = message }
	
	if not dir.dir_exists(saved_games_path):
		_log_info("folder '%s/%s' does not exist; creating it" % [root_path, saved_games_path])
		
		var save_dir_result = dir.make_dir(saved_games_path)
		
		if save_dir_result != OK:
			var message = "can't create '%s' folder" % saved_games_path
			_log_error(message)
			return { valid = false, message = message }
	
	var save_dir_result = dir.change_dir(saved_games_path)
	
	if save_dir_result != OK:
		var message = "can't open '%s' folder" % saved_games_path
		_log_error(message)
		return { valid = false, message = message }
	
	return { valid = true, folder = dir }
	
