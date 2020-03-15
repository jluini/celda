extends Node

export (NodePath) var room_place_path

var _room_place: Node

func _ready():
	_room_place = get_node(room_place_path)
	

func load_room(room_to_load):
	
	var room_scene = room_to_load.room_scene
	
	var room = room_scene.instance()
	
	# makes _room_place empty
	while _room_place.get_child_count():
		var first_child = _room_place.get_child(0)
		_room_place.remove_child(first_child)
		first_child.queue_free()
	
	_room_place.add_child(room)
