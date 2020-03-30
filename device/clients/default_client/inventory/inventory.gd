extends Control

export (int) var num_rows = 2
export (int) var num_cols = 4

var _num_holders

var _holders = []
var _items = []
var _offset = 0

func _ready():
	_num_holders = num_rows * num_cols
	
	for c in get_children():
		if c.get_name().begins_with("elem"):
			_holders.append(c)
	
	if _holders.size() != _num_holders:
		print("Expected %s cells, %s found" % [_num_holders, _holders.size()])
	
func clear():
	_items = []
	_update_arrows()
	_redraw_all()
	
func add_item(item_resource):
	var index = _items.size()
	_items.append(item_resource)
	
	var holder = current_holder_for_index(index)
	
	if holder:
		_draw_item(holder, item_resource)
	else:
		# scroll to bottom to show it
		while _can_go_down():
			_offset += 1
		_redraw_all()
	
	_update_arrows()

func remove_item(_item_resource):
	print("Implement remove_item")
	
func _draw_item(holder, item_resource):
	var texture = null
	if item_resource:
		texture = item_resource.texture
	holder.get_node("image").texture = texture

func current_holder_for_index(index: int) -> Node:
	var minimum_shown = _offset * num_cols
	var maximum_shown = (_offset + num_rows) * num_cols - 1
	
	if index >= minimum_shown and index <= maximum_shown:
		return _holders[index - minimum_shown]
	else:
		return null
	
func _can_go_up():
	return _offset > 0

func _can_go_down():
	return _items.size() > (num_rows + _offset) * num_cols

func _on_up_pressed():
	if _can_go_up():
		_offset -= 1
		_redraw_all()
		_update_arrows()

func _on_down_pressed():
	if _can_go_down():
		_offset += 1
		_redraw_all()
		_update_arrows()
	

func _redraw_all():
	for holder_index in range(_num_holders):
		var item_index = _offset * num_cols + holder_index
		if item_index < _items.size():
			var _item_resource = _items[item_index]
			_draw_item(_holders[holder_index], _item_resource)
		else:
			_draw_item(_holders[holder_index], null)

func _update_arrows():
	_set_arrow($arrow_up, _can_go_up())
	_set_arrow($arrow_down, _can_go_down())

func _set_arrow(arrow, value):
	var enabled_color = Color.white
	var disabled_color = Color("#696969")
	
	arrow.modulate = enabled_color if value else disabled_color
	arrow.get_node("TextureButton").disabled = not value

func get_item_at(global_position: Vector2):
	var rect: Rect2 = self.get_global_rect()
	if not rect.has_point(global_position):
		return
	
	for holder_index in range(_num_holders):
		var holder = _holders[holder_index]
		if holder.get_global_rect().has_point(global_position):
			var item_index = _offset * num_cols + holder_index
			if item_index < _items.size():
				var _item_resource = _items[item_index]
				return _item_resource
	
	return null
