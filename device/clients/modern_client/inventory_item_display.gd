extends Control

var _item_instance = null

func set_item(item_instance: Object):
	_item_instance = item_instance
	
	var texture: Texture = item_instance.get_texture()
	var image_display: TextureRect = $item_box/image
	
	image_display.texture = texture
	#image.modulate = modulate

func get_item_instance():
	return _item_instance

func is_scene_item() -> bool:
	return false

func get_item_rect() -> Rect2:
	return get_global_rect()
