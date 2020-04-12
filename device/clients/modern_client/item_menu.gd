extends Control

signal item_action # (item, action_name)

onready var _item_actions = $actions
onready var _item_name = $actions/item_name/label

var _client

var _actions = []

func init(p_client, data):
	_client = p_client
	
	#warning-ignore:return_value_discarded
	_item_actions.connect("on_element_selected", self, "_on_action_selected")
	
	for action_name in data.actions:
		# TODO fix this!
		if action_name == "use":
			continue
		
		var new_elem = _item_actions.add_element(action_name)
		
		_actions.append({
			action_name = action_name,
			menu_element = new_elem
		})

func _on_item_selected(item: Node, position): # is_inventory: bool):
	_item_name.text = _client.capitalize_first(_client._item_name(item))

	_item_actions.deselect()

	var num_actions = 0
	
	for i in range(_actions.size()):
		var action_name = _actions[i].action_name
		var menu_element = _actions[i].menu_element

		if not item.has_action(action_name):
			menu_element.hide()
		else:
			num_actions += 1
			menu_element.show()
	
	var width = rect_size.x
	
	var real_size = Vector2(width, 80 * (num_actions + 1))
	
	rect_size = real_size
	
	var item_position = position #item.position if not is_inventory else item.global_position
	
	var center = item_position - Vector2(width - 100, 0)
	
	var pos: Vector2 = center - real_size / 2
	
	if pos.y < 0:
		pos.y = 0
	if pos.x < 0:
		pos.x = 0
	
	rect_position = pos # item_position - Vector2(rect_size.x + 100, 0)
	
	show()

func _on_item_deselected(_item: Node):
	hide()

func _on_action_selected(_old_action, new_action: Node):
	emit_signal("item_action", null, new_action)
