extends Control

onready var _rows: Node = $rows
onready var _item_name_label: Label = $rows/header/item_name_container/item_name

func set_item(item, actions: Array):
	var item_name: String = item.get_item_name()
	var capitalized_item_name: String = item_name.capitalize()
	
	_item_name_label.text = capitalized_item_name
	
	_erase_rows()
	
	for action in actions:
		var action_string := action as String
		var action_name: String = tr("ACTION_" + action_string.to_upper())
		var capitalized_action_name: String = action_name.capitalize()
		
		var action_entry: Node = preload("res://clients/modern_client/item_action.tscn").instance()
		
		action_entry.get_node("action_name").text = capitalized_action_name
		
		_rows.add_child(action_entry)

func _erase_rows():
	while _rows.get_child_count() > 1:
		_rows.remove_child(_rows.get_child(1))
