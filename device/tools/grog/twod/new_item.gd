tool

extends Node2D

export (String) var key = "room/new_item"

export (Vector2) var size = Vector2(100, 100) setget set_size
export (Vector2) var offset = Vector2.ZERO setget set_offset

export (int) var interaction_angle = 90

export (Color) var color = Color.white

func _ready():
	if Engine.editor_hint:
		set_notify_local_transform(true)

func get_key() -> String:
	return key

func get_item_name() -> String:
	return tr("ITEM_" + get_key().to_upper())

func get_interact_position() -> Vector2:
	if has_node("interact_position"):
		var interact_position_child : Node2D = get_node("interact_position")
		return interact_position_child.global_position
	else:
		return global_position

func set_size(new_size: Vector2):
	size = new_size
	update()

func set_offset(new_offset: Vector2):
	offset = new_offset
	update()

func get_rect() -> Rect2:
	var ret: Rect2 = _relative_rect()
	ret.position += position
	return ret

func enable() -> void:
	set_visible(true)

func disable() -> void:
	set_visible(false)

func _relative_rect() -> Rect2:
	return Rect2(offset - size / 2, size)

func _draw():
	if Engine.editor_hint:
		_draw_rect()

func _draw_rect(rect_color: Color = color):
	draw_rect(_relative_rect(), rect_color, false, 4.0)

func _notification(what):
	if Engine.editor_hint:
		match what:
			35: # NOTIFICATION_LOCAL_TRANSFORM_CHANGED = 35
				_update_z_index()

func _update_z_index():
	# TODO extract this logic
	var new_z_index = int(position.y)
	
	set_z_index(new_z_index)
