extends MenuButton

signal song_selected

var _popup

var _songs

func _ready():
	_popup = get_popup()
	
	_popup.connect("id_pressed", self, "_on_option_selected")

func set_songs(song_list):
	_songs = song_list
	
	for song in song_list:
		_popup.add_item(song.get_name())

func _on_option_selected(_new_option):
	var new_song = _songs[_new_option]
	
	emit_signal("song_selected", new_song)
