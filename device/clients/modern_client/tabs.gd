extends Control

export (int) var initial_tab = -1

var _tabs = []
var _tabs_by_name = {}

var _num_tabs = 0

var _current_index: int = -1
var _current_view: Control = null

func _ready():
	for i in range(get_child_count()):
		var child = get_child(i)
		var name = child.get_name()
		var new_tab = {
			index = i,
			view = child,
			name = name
		}
		_tabs.append(new_tab)
		
		_tabs_by_name[name] = new_tab
	
	_num_tabs = _tabs.size()
	
	_current_index = initial_tab
	
	if _num_tabs == 0:
		print("No tabs")
		return
	elif _current_index < -1 or _current_index >= _num_tabs:
		print("Initial tab %s is invalid" % initial_tab)
		_current_index = -1
	
	# shows current tab and hides others
	for i in range(_num_tabs):
		var tab = _tabs[i]
		if i == _current_index:
			tab.view.show()
			_current_view = tab.view
		else:
			tab.view.hide()

func show_index(_tab_index: int):
	print("TODO implement")
	pass # TODO implement

func show_named(tab_name: String):
	if _tabs_by_name.has(tab_name):
		var tab = _tabs_by_name[tab_name]
		_current_index = tab.index
		if _current_view:
			_current_view.hide()
		_current_view = tab.view
		_current_view.show()
		

