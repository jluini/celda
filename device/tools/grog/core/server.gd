extends "res://tools/modular/module.gd"

export (String) var saved_games_path = "user://saved_games"

export (Resource) var game_script

onready var compiler = $compiler

var _compiled_game = null

var game_instance = null

func _on_initialize() -> Dictionary:
	if not game_script:
		return { valid = false, message = "There's no game set" }
	
	var res = game_script.prepare(compiler)
	
	if not res.result:
		# invalid game
		return res
	
	var dir = Directory.new()
	
	var user_dir_result = dir.open("user://")
	
	if user_dir_result != OK:
		return { valid = false, message = "Can't create files" }
	
	if not dir.dir_exists(saved_games_path):
		print("Folder 'saved_games' does not exist; creating it")
		dir.make_dir(saved_games_path)
	
	return { valid = true }

func get_module_name() -> String:
	return "grog-server"

func get_signals() -> Array:
	return []

func _process(delta):
	if game_instance:
		game_instance.update(delta)

func get_game_script():
	if not game_script:
		print("There's no game set")
	return game_script

func new_game():
	if not game_script:
		print("There's no game set")
		return
	
	assert(not game_instance)
	
	#game_instance = load("res://tools/grog/core/game_server.gd").new()
	game_instance = load("res://tools/grog/core/game_instance.gd").new()
	#add_child(server)
	
	var ok = game_instance.init(self, game_script)
	
	return game_instance

func get_saved_games():
	var ret = []
	var dir = Directory.new()
		
	var saved_games_result = dir.open(saved_games_path)
	if saved_games_result != OK:
		return { result = false, message = "Can't open folder" }
	
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
			#print("Directory found %s" % file_name)
			
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

