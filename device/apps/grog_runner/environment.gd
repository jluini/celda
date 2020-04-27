extends Node

signal environment_ready

#export (String) var user_dir_path = "user://"
#export (String) var saved_games_path = "saved_games"
export (String) var saved_games_path = "user://saved_games"

export (Resource) var game_to_play

export (String) var savegame_path = "user://saved_games/"

onready var _compiler = $compiler

var _compiled_game = null

var server = null

func initialize() -> Dictionary:
	if not game_to_play:
		return { result = false, msg = "There's no game set" }
	
	#_compiled_game = game_to_play.get_compiled()
	var res = game_to_play.prepare(_compiler)
	
	#if not game_to_play.valid():
	if not res.result:
		# invalid game
		return res
		#return { result = false, msg = "Game is not valid" }
	
	var dir = Directory.new()
	
	var user_dir_result = dir.open("user://")
	
	if user_dir_result != OK:
		return { result = false, message = "Can't create files" }
	
	if not dir.dir_exists(saved_games_path):
		print("Folder 'saved_games' does not exist; creating it")
		dir.make_dir(saved_games_path)
	
	emit_signal("environment_ready")
	
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
	
	server = load("res://tools/grog/newcore/server.gd").new()
	
	add_child(server)
	
	server.init(game_to_play)
	
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
