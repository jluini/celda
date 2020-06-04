extends AudioStreamPlayer

class_name LoopinStreamPlayer

var key: String

var _playing_since: int
var _playing_from: float

var _length: float
var _initial_time_to_next_mix: float
var _initial_output_latency: float

#var playback: AudioStreamPlayback = null # Actual playback stream, assigned in _ready().

func _ready():
	#playback = get_stream_playback()
	pass

var _now

func _init(_key):
	key = _key

func play_now(now: int, from_position = 0.0):
	_now = now
	_play(now, from_position)

func play(_from_position = 0.0):
	print("Don't call me!")

func _play(now: int, from_position = 0.0):
	if is_playing():
		print("Already playing")
		return
	
	_length = stream.get_length()
	
	if from_position < 0:
		print("Negative start point")
		return
	elif from_position > _length:
		print("Start point out of bounds (%f > %f)" % [from_position, _length])
		return
		
	.play(from_position)
	
	_initial_time_to_next_mix = AudioServer.get_time_to_next_mix()
	_initial_output_latency = AudioServer.get_output_latency()
	
	var delay = max(0, _initial_time_to_next_mix) + _initial_output_latency
	
	_playing_since = now + int(delay * 1000000.0)
	_playing_from = from_position

func time_to_next_mix() -> float:
	return max(0, AudioServer.get_time_to_next_mix()) + AudioServer.get_output_latency()

func estimated_playback_position(now: int, in_future = false) -> float:
	var elapsed_ticks: int = now - _playing_since
	
	var elapsed: float = elapsed_ticks / 1000000.0
	
	var ret = _playing_from + elapsed
	
	if in_future:
		ret += time_to_next_mix()
	
	return fmod(ret, _length)

