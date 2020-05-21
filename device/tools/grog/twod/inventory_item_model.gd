extends Node

func get_key() -> String:
	return get_name() # returns the Node name

func get_texture() -> Texture:
	return $sprite.texture
