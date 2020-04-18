extends Node

signal song_started
signal song_ended

signal state_changed

enum EndMode {

	Default,
	AlwaysFedeOut,
	AlwaysSudden

}
export (EndMode) var end_mode = EndMode.Default

export (float) var separation_length = 0.5
export (float) var fedeout_length = 4
export (float) var afterfinal_length = 2.5

var _afterfinal_length_usec: int
var _fedeout_length_usec: int
var _separation_length_usec: int

enum State {
	Stopped,
	Playing,
	WaitingEnd,
	Ending,
	Waiting
}
var _state = State.Stopped
onready var _last_state_change = ticks_now()

var _fede_out = false
var _after_final = false

var _next_song
var _ending_time_calculated: bool
var _ending_point: float

var _current_song: Resource = null

var _main_loop: AudioStreamPlayer
var _final: AudioStreamPlayer

var _player_pool

func _ready():
	set_separation_length(separation_length)
	set_afterfinal_length(afterfinal_length)
	set_fedeout_length(fedeout_length)
	
	_player_pool = AudioPlayerPool.new()
	
	add_child(_player_pool)
	
	_player_pool.connect("player_finished", self, "_on_player_finished")
	set_process(false)
	
func _process(_delta):
	var now: int = ticks_now()
	
	if _state == State.Waiting:
		var elapsed: int = now - _last_state_change
		
		if elapsed >= _separation_length_usec:
			_set_state(State.Stopped)
			set_process(false)
			
			if _next_song:
				_loop_song(_next_song)
				_next_song = null
		
		return
	
	elif _state == State.Ending:
		if _fede_out:
			var elapsed: int = ticks_now() - _last_state_change
			
			var _from = 0.0
			var _to = -80.0
			
			if elapsed >= _fedeout_length_usec:
				_end_song()
				_fede_out = false
			else:
				var _range: float = float(elapsed) / _fedeout_length_usec
				var new_volume = _from + _range * (_to - _from)
				_main_loop.volume_db = new_volume
		
		elif _after_final:
			var elapsed: int = ticks_now() - _last_state_change
			
			if elapsed >= _afterfinal_length_usec:
				_end_song()
				_after_final = false

		return
	
	var estimated: float = _main_loop.estimated_playback_position(now, true)
	
	var estimated_future: float = estimated + 0.015
	
	match _state:
		State.Playing:
			pass
			
		State.WaitingEnd:
			if not _ending_time_calculated:
				_ending_time_calculated = true
				
				_ending_point = _calculate_ending_point(estimated_future)
			
			if estimated_future >= _ending_point:
				#var diffe: int = int((estimated - _ending_point) * 1000000.0)
				#print("Ending by %d microseconds" % diffe)
				
				_set_state(State.Ending)
				
				var _final_end_mode = _current_song.end_mode
				
				if end_mode == EndMode.AlwaysFedeOut:
					_final_end_mode = SongResource.EndMode.FedeOut
				elif end_mode == EndMode.AlwaysSudden:
					_final_end_mode = SongResource.EndMode.Sudden
				
				match _final_end_mode:
					SongResource.EndMode.Final:
						_expecting_to_finish["main_loop"] = "nothing"
						_main_loop.stop()
					
						_expecting_to_finish["final"] = "end"
						_final.play_now(now)
					
					SongResource.EndMode.Sudden:
						_expecting_to_finish["main_loop"] = "nothing"
						_main_loop.stop()
						_after_final = true
					
					SongResource.EndMode.FedeOut:
						# fede out
						_fede_out = true
						
					_:
						print("Error")
		
		_:
			print("Unexpected _process")

	for c in get_tree().get_nodes_in_group("playback_time"):
		c.text = "%2.3f" % estimated
	
func loop_song(song: Resource) -> bool:
	match _state:
		State.Stopped:
			_loop_song(song)
			
			return true
		
		State.Playing:
			_set_state(State.WaitingEnd)
			_next_song = song
			_ending_time_calculated = false
			
			return true
		
		State.WaitingEnd, State.Ending, State.Waiting:
			_next_song = song
			return true
		
		_:
			print("Unexpected state %s" % State.keys()[_state])
			return false

func _loop_song(song):
	if not song.check_loop():
		print("Invalid song")
		return false
	
	assert(not _current_song)
	
	_current_song = song
	
	_main_loop = _player_pool.new_player("main_loop", song.main_loop_stream)
	_final = null
	if song.final_stream:
		_final = _player_pool.new_player("final", song.final_stream)
	
	_set_state(State.Playing)
	
	var now = ticks_now()
	_main_loop.play_now(now)
	
	set_process(true)
	
	emit_signal("song_started", song)

func stop() -> bool:
	match _state:
		State.Stopped:
			return false
		
		State.Playing:
			_set_state(State.WaitingEnd)
			_next_song = null
			_ending_time_calculated = false
			
			return true
		
		State.WaitingEnd, State.Ending, State.Waiting:
			_next_song = null
			return true
			
		_:
			print("Unexpected state %s" % State.keys()[_state])
			return false

func ticks_now():
	return OS.get_ticks_usec()

var _expecting_to_finish = {}

func _end_song():
	emit_signal("song_ended", _current_song)
	
	if _state != State.Ending and _state != State.WaitingEnd:
		print("Unexpected state %s in _end_song" % State.keys()[_state])
	
	_current_song = null
	
	_player_pool.remove_player("main_loop")
	_main_loop = null
	if _final:
		_player_pool.remove_player("final")
		_final = null
	
	_set_state(State.Waiting)
	
func _on_player_finished(key: String):
	if not _expecting_to_finish.has(key):
		print("Unexpected finish of player '%s'" % key)
	else:
		var finishing = _expecting_to_finish[key]
		
		if finishing == "nothing":
			pass
		elif finishing == "end":
			_after_final = true
			_last_state_change = ticks_now()

func _set_state(_new_state):
	_state = _new_state
	_last_state_change = ticks_now()
	
	var _state_name: String = State.keys()[_state]
	emit_signal("state_changed", _state_name)

func _calculate_ending_point(starting_at: float) -> float:
	if end_mode == EndMode.Default:
		return _current_song.get_next_ending_point(starting_at)
	else:
		return starting_at

func get_end_mode():
	return end_mode


func set_separation_length(value):
	separation_length = value
	_separation_length_usec = int(value * 1000000.0)
	
func set_fedeout_length(value):
	fedeout_length = value
	_fedeout_length_usec = int(value * 1000000.0)
	
func set_afterfinal_length(value):
	afterfinal_length = value
	_afterfinal_length_usec = int(value * 1000000.0)
	
	
