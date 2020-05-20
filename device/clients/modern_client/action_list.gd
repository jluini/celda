extends Control

onready var _rows: Node = $rows
onready var _item_name_label: Label = $rows/header/item_name_container/item_name

var _current_actions := []

func set_item(item, actions: Array):
	var item_name: String = item.get_item_name()
	var capitalized_item_name: String = item_name.capitalize()
	
	_item_name_label.text = capitalized_item_name
	
	_erase_actions()
	
	for action in actions:
		var action_string := action as String
		
		var action_name: String = tr("ACTION_" + action_string.to_upper())
		var capitalized_action_name: String = action_name.capitalize()
		
		var action_entry: Control = preload("res://clients/modern_client/item_action.tscn").instance()
		
		_current_actions.append({
			entry = action_entry,
			name = action_string
		})
		
		action_entry.get_node("action_name").text = capitalized_action_name
		
		_rows.add_child(action_entry)

func get_item_action_at(position: Vector2) -> String:
	for action in _current_actions:
		var entry : Control = action.entry
		var action_name : String = action.name
		
		var rect: Rect2 = entry.get_global_rect()
		
		if rect.has_point(position):
			return action_name
	
	return ""

func _erase_actions():
	_current_actions = []
	_erase_rows()

func _erase_rows():
	while _rows.get_child_count() > 1:
		_rows.remove_child(_rows.get_child(1))
