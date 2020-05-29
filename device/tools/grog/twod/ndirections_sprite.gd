extends Node

# Each direction ends in one angle.
# The angles must be positive and increasing.
# 0.0 is facing right, 90.0 front, etc...
export (Array, Dictionary) var config = []

export (NodePath) var animation_path
export (NodePath) var sprite_path

# Expected to be AnimationPlayer. We use play(String).
var _animation

# Expected to be Sprite or AnimatedSprite. We use flip_h and flip_v properties.
var _sprite

var walking = false
var orientation := 0.0

func _get_sprite():
	if not _sprite:
		_sprite = get_node(sprite_path)
	return _sprite

func _on_start_walking(new_orientation: float):
	orientation = _normalize_angle(new_orientation)
	walking = true
	
	var index = _get_direction_index()
	var key: String = config[index].walk
	
	play_animation(key)

func _on_orientation_changed(new_orientation: float):
	orientation = _normalize_angle(new_orientation)
	
	var index = _get_direction_index()
	var key: String = config[index].walk if walking else config[index].idle
	
	play_animation(key)

func _on_stop_walking() -> void:
	walking = false
	
	var index = _get_direction_index()
	var key: String = config[index].idle
	
	play_animation(key)

func play_animation(key: String) -> void:
	var keys: Array = key.split(".", false)
	var animation_name = keys.pop_front()
	
	_get_sprite().flip_h = keys.has("flip_h")
	_get_sprite().flip_v = keys.has("flip_v")

	_get_animation().play(animation_name)

func _get_animation():
	if not _animation:
		_animation = get_node(animation_path)
	return _animation

# Misc

# Return the index of the first element greater than the normalized orientation, or 0
func _get_direction_index() -> int:
	for i in range(config.size()):
		if orientation < config[i].value:
			return i
	
	return 0

static func _normalize_angle(angle: float) -> float:
	while angle < 0:
		angle += 360.0
	while angle >= 360.0:
		angle -= 360.0
	return angle
