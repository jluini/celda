tool

extends Node2D

export (String) var key = "room/new_item"

export (Vector2) var size = Vector2(100, 100) setget set_size
export (Vector2) var offset = Vector2.ZERO setget set_offset

export (Color) var color = Color.white

# Game state
var _enabledness: bool
var _state: String

func _ready():
	if Engine.editor_hint:
		set_notify_local_transform(true)

func is_scene_item() -> bool:
	return true

func get_key() -> String:
	return key

func get_id() -> String:
	return key # id and key are the same for a scene item

func get_item_name() -> String:
	return tr("ITEM_" + get_key().to_upper())

### Game state

func load_item(enabledness: bool, state: String):
	_enabledness = enabledness
	_state = state
	
	if enabledness:
		# warning-ignore:return_value_discarded
		_play_animation()
	else:
		set_visible(false)

func enable() -> void:
	_enabledness = true
	
	# warning-ignore:return_value_discarded
	_play_animation()
	
	set_visible(true)

func disable() -> void:
	_enabledness = false
	set_visible(false)
	_stop_animation()

func set_state(new_state: String) -> float:
	var ret := 0.0
	
	_state = new_state
	
	if _enabledness:
		ret = _play_animation()
	
	return ret

###

func _play_animation() -> float:
	var ret := 0.0
	
	if has_node("animation"):
		var anim: AnimationPlayer = get_node("animation")
		
		if anim.has_animation(_state):
			anim.play(_state)
			ret = anim.current_animation_length
		else:
			push_warning("item '%s': no animation '%s'" % [key, _state])
	
	return ret

func _stop_animation():
	if has_node("animation"):
		var anim: AnimationPlayer = get_node("animation")
		anim.stop(false)

###

func get_interact_location() -> Vector2:
	if has_node("positioning"):
		return get_node("positioning").get_location()
	else:
		return global_position

func get_interact_orientation() -> float:
	if has_node("positioning"):
		return get_node("positioning").get_orientation()
	else:
		print("Returning 90.0 as default orientation")
		return 90.0

func set_size(new_size: Vector2):
	size = new_size
	update()

func set_offset(new_offset: Vector2):
	offset = new_offset
	update()

func get_item_rect() -> Rect2:
	var ret: Rect2 = _relative_rect()
	ret.position += position
	return ret

func _relative_rect() -> Rect2:
	return Rect2(offset - size / 2, size)

func _draw_rect(rect_color: Color = color):
	draw_rect(_relative_rect(), rect_color, false, 4.0)

func _draw():
	if Engine.editor_hint:
		_draw_rect()

func _notification(what):
	if Engine.editor_hint:
		match what:
			35: # NOTIFICATION_LOCAL_TRANSFORM_CHANGED = 35
				_update_z_index()

func _update_z_index():
	# TODO extract this logic
	var new_z_index = int(position.y)
	
	set_z_index(new_z_index)
