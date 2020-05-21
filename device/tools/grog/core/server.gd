extends "res://tools/modular/module.gd"

export (String) var root_path = "user://"
export (String) var saved_games_path = "saved_games"
export (String) var quick_save_path = "quicksave.tres"

export (Resource) var game_script

onready var compiler = $compiler

var _compiled_game = null

var game_instance: Node = null

var _start_list_button_group = ButtonGroup.new()
var _initial_stage := 0

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
	
	var stages : Array = game_script.get_stages()
	
	if stages.size() == 0:
		_log_error("there's no stages in script")
	
	for s in range(stages.size()):
		var stage_name: String = stages[s]
		
		var stage_button := Button.new()
		
		stage_button.text = str(s) + ": " + stage_name
		
		stage_button.toggle_mode = true
		stage_button.group = _start_list_button_group
		
		if s == 0:
			stage_button.pressed = true
		
		# warning-ignore:return_value_discarded
		stage_button.connect("pressed", self, "_on_stage_button_pressed", [s, stage_name])
		
		$control3/start_list.add_child(stage_button)
	
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

func new_game_from(filename: String) -> Dictionary:
	if not game_script:
		var message = "there's no game set"
		_log_warning(message)
		return { valid = false, message = message }
	
	if game_instance:
		var message = "there's still another game"
		_log_warning(message)
		return { valid = false, message = message }
	
	game_instance = load("res://tools/grog/core/game_instance.gd").new()
	game_instance.name = "game_instance"
	
	# make game pausable
	game_instance.pause_mode = PAUSE_MODE_STOP
	
	var saved_game: Resource = null
	
	if filename != "":
		var full_path: String = _save_game_path(filename)
		saved_game = load(full_path)
		
		if saved_game == null:
			_log_warning("couldn't read saved game '%s', playing from start" % filename)
	
	var init_game_result: Dictionary = game_instance.init_game(self, game_script, saved_game, _initial_stage)
	
	if not init_game_result.valid:
		_log_debug("deleting game instance")
		game_instance.queue_free()
		return init_game_result
	
	add_child(game_instance)
	
	return { valid = true, game_instance = game_instance }

func delete_game() -> Dictionary:
	if not game_instance:
		return { valid = false, message = "no game to delete" }
	
	game_instance.release()
	game_instance.free()
	
	game_instance = null
	
	return { valid = true }

func get_saved_games() -> Dictionary:
	var save_folder_result: Dictionary = _get_or_create_save_folder()
	
	if not save_folder_result.valid:
		save_folder_result.saved_games = []
		return save_folder_result
	
	var dir: Directory = save_folder_result.folder
	var saved_games := []
	
	if dir.list_dir_begin() != OK:
		return {
			valid = false,
			message = "can't iterate savegame directory",
			saved_games = []
		}
	
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			# TODO check file
			
			var name = file_name
			
			saved_games.append({
				filename = file_name,
				name = name
			})
		else:
			pass # Ignoring dir
			
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return {
		valid = true,
		saved_games = saved_games
	}

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
	var full_path := _save_game_path(path)
	
	_log_debug("trying to save game in '%s'" % full_path)
	
	var saved_game := SavedGame.new()
	saved_game.read_from(game_instance)
	var save_result = ResourceSaver.save(full_path, saved_game, ResourceSaver.FLAG_CHANGE_PATH)
	
	if save_result != OK:
		var message = "couldn't save to '%s' (error %s)" % [full_path, save_result]
		_log_error(message)
		return { valid = false, message = message }
	
	return { valid = true }

func _save_game_path(saved_game_name: String) -> String:
	return "%s%s/%s" % [root_path, saved_games_path, saved_game_name]

func _on_list_saved_games_pressed():
	_modular.make_empty($control/saved_games)
	
	var saved_games_result = get_saved_games()
	var saved_games: Array = saved_games_result.saved_games
	
	# TODO check saved_games_result.valid and show message if there's error
	
	for sg in saved_games:
		var new_label = Label.new()
		new_label.text = sg.filename
		$control/saved_games.add_child(new_label)

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

# TODO revise this
func _on_save_button_pressed():
	var save_result = save_game()
	
	if save_result.valid:
		_log_debug("game saved!")
	else:
		_log_error("couldn't save")

func _on_stage_button_pressed(stage_index: int, _stage_name: String):
	_initial_stage = stage_index
