extends Node

var _grog_game

onready var environment = $environment
onready var client = $client

func _ready():
	if not environment:
		print("    please set an environment")
		return
	
	if not client:
		print("    please set a client")
		return
	
	client._pre_init()
	
	var e = environment.initialize()
	if e.result:
		client.init(environment)
	else:
		client.show_error(e.message if e.message else "error...")
		
	
#func _on_environment_ready():
#	client.init(environment)
	
#	_grog_game = GameServer.new()
#	var is_valid = _grog_game.init_game(_compiler, game_to_play, GameServer.StartMode.Default, starting_index)
#	#if actor:
#	#	_grog_game.set_player(actor)
#	if is_valid:
#		_ui.hide()
#
#		current_display.init(_grog_game)
#	else:
#		print("Invalid start")


func _on_client_game_ended():
	pass # Replace with function body.


func _on_client_music_changed():
	pass # Replace with function body.

