extends Node

export (bool) var start_game_automatically

export (Array, Resource) var displays

export (Resource) var game_to_load

export (NodePath) var ui_path
export (NodePath) var display_path

export (NodePath) var game_name_label_path
#export (NodePath) var room_list_path
#export (NodePath) var script_list_path
export (NodePath) var display_list_path
export (NodePath) var start_list_path
export (NodePath) var actor_list_path

#export (NodePath) var raw_script_edit_path

onready var _compiler = $grog_compiler

var _grog_game: GameServer = null

onready var _ui = get_node(ui_path)
#onready var _display = get_node(display_path)

onready var _game_name_label = get_node(game_name_label_path)
#onready var _room_list = get_node(room_list_path)
#onready var _script_list = get_node(script_list_path)
onready var _display_list = get_node(display_list_path)
onready var _start_list = get_node(start_list_path)
onready var _actor_list = get_node(actor_list_path)

#onready var _raw_script_edit = get_node(raw_script_edit_path)

#var _default_script

var current_display: Node = null

func _ready():
	if not game_to_load:
		push_error("No game_to_load")
		return
	
	#_default_script = _raw_script_edit.text
	
	_game_name_label.set_text(game_to_load.get_name())
	
	#list_elements("rooms", game_to_load.get_all_rooms(), _room_list)
	#list_elements("scripts", game_to_load.get_all_scripts(), _script_list, false)
	
	if not displays:
		push_error("At least one display needed")
		return
	
	list_elements("displays", displays, _display_list)
	list_elements("starts", game_to_load.get_all_scripts(), _start_list)
	list_elements("actors", game_to_load.get_all_actors(), _actor_list)
	
	#_script_list.connect("on_element_selected", self, "_on_script_selected")
	#_script_list.connect("on_element_deselected", self, "_on_script_deselected")
	
	if start_game_automatically:
		play_game(displays[0], null, 0)
	
func list_elements(name: String, elements: Array, list: Node, select_first = true):
	if not list:
		push_error("No list node for %s" % name)
		return
	
	for element in elements:
		list.add_element(element)
	
	if select_first:
		list.select_first()

#func _on_script_selected(_old_script, _new_script):
#	_raw_script_edit.text = _new_script.target.get_code()

#func _on_script_deselected(_old_script):
#	_raw_script_edit.text = _default_script
	
#func _on_test_room_button_pressed():
#	var current_room = _room_list.get_current()
#
#	if not current_room:
#		return
#
#	var current_player = _actor_list.get_current()
#
#	test_room(current_room, current_player)

func _on_play_game_button_pressed():
	if not _display_list.has_current():
		print("Select a display please")
		return
	
	var index = _start_list.get_current_index() if _start_list.has_current() else 0
	
	play_game(_display_list.get_current(), _actor_list.get_current(), index)
	
#func _on_test_script_button_pressed():
#	var script_text = _raw_script_edit.text
#
#	play_game(null, GameServer.StartMode.FromRawScript, script_text)
	
func _on_quit_button_pressed():
	get_tree().quit()
	
#func test_room(_room_resource, _actor_resource):
	#var compiled_script = CompiledGrogScript.new()
	#var start_sequence = build_start_sequence(_room_resource)
	
	#compiled_script.add_sequence("start", start_sequence)
	
#	play_game(_actor_resource, GameServer.StartMode.FromRoom, _room_resource)

#func build_start_sequence(room_resource):#, actor_resource):
#	var ret = []
#
#	ret.append({ type="command", command="load_room", params=[room_resource.get_name()] })
#	ret.append({ type="command", command = "enable_input", params = [] })
#
#	return { statements=ret, telekinetic=false }

#func play_game(actor, game_mode = GameServer.StartMode.Default, param = null):
func play_game(display_resource: Resource, actor, starting_index: int):
	if current_display:
		print("Undeleted old display!!")
		return
	
	var display_scene = display_resource.get_target()
	current_display = display_scene.instance()
	
	var _r = current_display.connect("game_ended", self, "_on_game_ended")
	
	add_child(current_display)
	
	_grog_game = GameServer.new()

	var is_valid = _grog_game.init_game(_compiler, game_to_load, GameServer.StartMode.Default, starting_index)

	if actor:
		_grog_game.set_player(actor)

	if is_valid:
		_ui.hide()
		#current_display.show()
		current_display.init(_grog_game)
	else:
		print("Invalid start")
	
func _on_game_ended():
	_grog_game = null
	#current_display.hide()
	remove_child(current_display)
	current_display.queue_free()
	current_display = null
	_ui.show()
