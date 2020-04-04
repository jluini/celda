extends Node

# Each direction ends in one angle.
# The angles must be positive and increasing.
# 0.0 is facing right, 90.0 front, etc...
export (Array, Dictionary) var config = []

export (NodePath) var animation_path
export (NodePath) var sprite_path

# Expected to be AnimationPlayer. We use play(String).
onready var _animation = get_node(animation_path)

# Expected to be Sprite or AnimatedSprite. We use flip_h and flip_v properties.
var _sprite

var walking = false
var angle = 0
#var last_angle: int = 0

func _get_sprite():
	if not _sprite:
		_sprite = get_node(sprite_path)
	return _sprite

func _on_start_walking(new_angle: int):
	angle = new_angle
	walking = true
	
	var index = get_range_index(angle, config)
	var key = config[index].walk
	
	play_animation(key)

func _on_angle_changed(new_angle: int):
	angle = new_angle
	var index = get_range_index(angle, config)
	var key = config[index].walk if walking else config[index].idle
	play_animation(key)
	
	
func _on_stop_walking():
	walking = false
	
	var key: String = config.back().idle
	
	var index = get_range_index(angle, config)
	key = config[index].idle
	
	play_animation(key)
	
func play_animation(key):
	var keys: Array = key.split(".", false)
	var animation_name = keys.pop_front()

	_get_sprite().flip_h = keys.has("flip_h")
	_get_sprite().flip_v = keys.has("flip_v")

	_animation.play(animation_name)
	
# Misc

# Return the index of the first element greater than the reference value, or 0
func get_range_index(value, cut_values: Array) -> int:
	for i in range(cut_values.size()):
		if value < cut_values[i].value:
			return i
	
	return 0
