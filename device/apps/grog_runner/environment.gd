extends Node

export (String) var saved_games_path = "user://saved_games"

export (Resource) var game_to_play

onready var compiler = $compiler

var _compiled_game = null

var server = null

func _process(delta):
	if server:
		server.update(delta)

func initialize() -> Dictionary:
	if not game_to_play:
		return { result = false, message = "There's no game set" }
	
	var res = game_to_play.prepare(compiler)
	
	if not res.result:
		# invalid game
		return res
	
	var dir = Directory.new()
	
	var user_dir_result = dir.open("user://")
	
	if user_dir_result != OK:
		return { result = false, message = "Can't create files" }
	
	if not dir.dir_exists(saved_games_path):
		print("Folder 'saved_games' does not exist; creating it")
		dir.make_dir(saved_games_path)
	
	return { result = true }
	
func get_game_data():
	if not game_to_play:
		print("There's no game set")
	return game_to_play

func new_game():
	if not game_to_play:
		print("There's no game set")
		return
	
	assert(not server)
	
	#server = load("res://tools/grog/newcore/server.gd").new()
	#add_child(server)
	
	server = load("res://tools/grog/core/game_server.gd").new()
	server.init(self, game_to_play)
	
	return server

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
