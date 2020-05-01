extends "res://tools/modular/module.gd"

export (Resource) var loopin_set

export (Dictionary) var state_colors = {
	Stopped = Color.black,
	Playing = Color(0, 0.5, 0),
	WaitingEnd = Color(0.5, 0.5, 0),
	Ending = Color(0.5, 0, 0),
	Waiting = Color(0.5, 0.5, 0.5),
}

var _loopin
var _songs

var _list
var _title
var _state_label
var _state_color
var _end_mode: MenuButton

# Module methods

#func _ready():
func _on_initialize() -> Dictionary:
	_loopin = $loopin_server
	_songs = loopin_set.songs if loopin_set else []
	
	# TODO fix these node paths...
	
	#var _divisions = $h_split_container/v_split_container/panel_container/panel/divisions
	
	_list = $h_split_container/v_split_container/panel_container/panel/divisions/control/list
	_title = $h_split_container/v_split_container/panel_container/panel/divisions/h_split_container/title
	
	_state_label = $h_split_container/v_split_container/panel_container/panel/divisions/h_split_container/control/state_label
	_state_color = $h_split_container/v_split_container/panel_container/panel/divisions/h_split_container/control/state_color
	_end_mode = $h_split_container/v_split_container/panel_container/panel/divisions/control2/end_mode_box/list
	
	_list.set_songs(_songs)
	_list.connect("song_selected", self, "_on_song_selected")
	
	_loopin.connect("song_started", self, "_on_song_started")
	_loopin.connect("song_ended", self, "_on_song_ended")
	_loopin.connect("state_changed", self, "_on_state_changed")
	
	var end_mode_index = _loopin.get_end_mode()
	var end_mode_name = _end_mode.get_popup().get_item_text(end_mode_index)
	
	var _r1 = _end_mode.connect("end_mode_selected", self, "_on_end_mode_selected")
	_end_mode.text = end_mode_name
	
	var sep = _get_setting("separation_length")
	var fed = _get_setting("fedeout_length")
	var aft = _get_setting("afterfinal_length")
	
	_set_length_label("separation_length", _loopin.separation_length)
	_set_length_slider(sep.get_node("h_slider"), _loopin.separation_length)
	_set_length_label("fedeout_length", _loopin.fedeout_length)
	_set_length_slider(fed.get_node("h_slider"), _loopin.fedeout_length)
	_set_length_label("afterfinal_length", _loopin.afterfinal_length)
	_set_length_slider(aft.get_node("h_slider"), _loopin.afterfinal_length)
	
	var _r2 = sep.get_node("h_slider").connect("value_changed", self, "_on_separation_length_value_changed")
	var _r3 = fed.get_node("h_slider").connect("value_changed", self, "_on_fedeout_length_value_changed")
	var _r4 = aft.get_node("h_slider").connect("value_changed", self, "_on_afterfinal_length_value_changed")
	
	return { valid = true }

func _get_setting(setting_name: String):
	var path = "h_split_container/v_split_container/panel_container/panel/divisions/%s" % setting_name
	return get_node(path)

func get_module_name() -> String:
	return "loopin"

func get_signals() -> Array:
	return [{
		category = "music",
		signal_name = "start",
		target = self,
		method_name = "play_song"
	}, {
		category = "music",
		signal_name = "stop",
		target = self,
		method_name = "stop"
	}]

# TODO classify behind this
	
func _on_song_started(song):
	_title.text = song.get_name()

func _on_song_ended(_song):
	_title.text = "------"

func _on_state_changed(_new_state):
	_state_label.set_text(_new_state)
	
	_state_color.modulate = state_colors[_new_state]

func _on_end_mode_selected(end_mode_index: int):
	print("index=%d"%end_mode_index)
	var end_mode_name = _end_mode.get_popup().get_item_text(end_mode_index)
	
	_end_mode.text = end_mode_name
	_loopin.end_mode = end_mode_index

func play_song(song_name: String):
	var done = false
	for s in _songs:
		if s.get_name() == song_name:
			_on_song_selected(s)
			done = true
			break
	
	if not done:
		print("Song '%s' not found" % song_name)

func _on_song_selected(song):
	if _loopin.loop_song(song):
		_list.set_text("PLAY (%s)" % song.get_name())

func _on_stop_button_pressed():
	stop()

func stop_now():
	#TODO stop now
	stop()

func stop():
	if _loopin.stop():
		_list.set_text("PLAY (nothing)")


func _on_separation_length_value_changed(value):
	_loopin.set_separation_length(value)
	_set_length_label("separation_length", value)
	
func _on_fedeout_length_value_changed(value):
	_loopin.set_fedeout_length(value)
	_set_length_label("fedeout_length", value)
	
func _on_afterfinal_length_value_changed(value):
	_loopin.set_afterfinal_length(value)
	_set_length_label("afterfinal_length", value)

func _set_length_slider(slider, value):
	slider.value = value

func _set_length_label(setting_name: String, value):
	var setting = _get_setting(setting_name)
	var label = setting.get_node("value")
	label.text = "%1.1f" % value
