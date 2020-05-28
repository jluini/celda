extends Control

# TODO name model is wrong! change it to 'instance' or something
var model = null

func set_model(item_model: Object):
	model = item_model
	
	var texture: Texture = model.get_texture()
	var image_display: TextureRect = $item_box/image
	
	image_display.texture = texture
	#image.modulate = modulate

func get_key():
	return model.get_key()

func get_id():
	return model.get_id()

func get_item_name() -> String:
	return tr("ITEM_" + get_key().to_upper())

func is_scene_item() -> bool:
	return false
