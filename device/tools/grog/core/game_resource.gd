extends Resource

class_name GameResource

export (String) var default_action

export (Array, String) var actions

export (Array, Resource) var scripts setget , get_all_scripts

export (Array, Resource) var rooms setget , get_all_rooms

export (Array, Resource) var actors setget , get_all_actors

export (Resource) var inventory_items_scene

func get_all_rooms():
	return rooms

func get_all_scripts():
	return scripts
	
func get_all_actors():
	return actors

