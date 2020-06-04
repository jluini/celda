extends Node2D

export (String) var left_action = "action1"
export (String) var right_action = "action2"

onready var _left_bubble = $bubble_anchor/bubbles/bubble_left
onready var _right_bubble = $bubble_anchor/bubbles/bubble_right

const maximum_distance2 = pow(60.0, 2)

func open():
	show()
	$animation.play("open")

func close():
	hide()

func get_item_action_at(clicked_position: Vector2) -> String:
	var left_bubble_position: Vector2 = _left_bubble.global_position
	var right_bubble_position: Vector2 = _right_bubble.global_position
	
	var left_distance2: float = clicked_position.distance_squared_to(left_bubble_position)
	
	if left_distance2 <= maximum_distance2:
		return left_action
		
	var right_distance2: float = clicked_position.distance_squared_to(right_bubble_position)
	
	if right_distance2 <= maximum_distance2:
		return right_action
	
	return ""
