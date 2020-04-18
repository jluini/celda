extends Node

export (bool) var start_game_automatically

export (Array, Resource) var displays

export (Resource) var game_to_load

export (NodePath) var ui_path
export (NodePath) var display_path

export (NodePath) var game_name_label_path
export (NodePath) var display_list_path
export (NodePath) var start_list_path
export (NodePath) var actor_list_path


onready var _compiler = $grog_compiler

var _grog_game: GameServer = null

onready var _ui = get_node(ui_path)

onready var _game_name_label = get_node(game_name_label_path)
onready var _display_list = get_node(display_list_path)
onready var _start_list = get_node(start_list_path)
onready var _actor_list = get_node(actor_list_path)


var current_display = null

func _ready():
	if not game_to_load:
		push_error("No game_to_load")
		return
	
	_game_name_label.set_text(game_to_load.get_name())
	
	if not displays:
		push_error("At least one display needed")
		return
	
	list_elements("displays", displays, _display_list)
	list_elements("starts", game_to_load.get_all_scripts(), _start_list)
	list_elements("actors", game_to_load.get_all_actors(), _actor_list)
	
	_display_list.select(1)
	_start_list.select(1)
	
	if start_game_automatically:
		_play()

func _process(delta):
	if _grog_game:
		_grog_game.update(delta)
	
func list_elements(name: String, elements: Array, list: Node, select_first = true):
	if not list:
		push_error("No list node for %s" % name)
		return
	
	for element in elements:
		list.add_element(element)
	
	if select_first:
		list.select_first()

func _on_play_game_button_pressed():
	_play()

func _play():
	if not _display_list.has_current():
		print("Select a display please")
		return
	
	var index = _start_list.get_current_index() if _start_list.has_current() else 0
	
	play_game(_display_list.get_current(), _actor_list.get_current(), index)
	
func _on_quit_button_pressed():
	get_tree().quit()
	
func play_game(display_resource: Resource, actor, starting_index: int):
	if current_display:
		print("Undeleted old display!!")
		return
	
	var display_scene = display_resource.get_target()
	current_display = display_scene.instance()
	
	var _r = current_display.connect("game_ended", self, "_on_game_ended")
	var _s = current_display.connect("music_changed", self, "_on_music_changed")
	
	add_child(current_display)
	
	_grog_game = GameServer.new()

	var is_valid = _grog_game.init_game(_compiler, game_to_load, GameServer.StartMode.Default, starting_index)

	if actor:
		_grog_game.set_player(actor)

	if is_valid:
		_ui.hide()
		
		current_display.init(_grog_game)
	else:
		print("Invalid start")
	
func _on_game_ended():
	$ui_layer/ui/loopin_display.stop_now()
	_grog_game = null
	
	remove_child(current_display)
	current_display.queue_free()
	current_display = null
	
	_ui.show()

func _on_music_changed(new_song):
	if not $ui_layer/ui/music/toggle.pressed:
		if new_song:
			$ui_layer/ui/loopin_display.play_song(new_song)
		else:
			$ui_layer/ui/loopin_display.stop()
