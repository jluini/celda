extends Resource

class_name SongResource

#export (Array, Resource) var pieces

export (AudioStreamOGGVorbis) var main_loop_stream
export (AudioStreamOGGVorbis) var final_stream

export (int) var number_of_measures

export (int) var measure_numerator
export (int) var measure_denominator

enum EndMode {
	FedeOut,
	Sudden,
	Final
}
export (EndMode) var end_mode = EndMode.Sudden

enum BreakingMode {
	End,
	Immediate,
	EveryNMeasures,
}

export (BreakingMode) var breaking_mode = BreakingMode.End
export (int) var breaking_measures

var _cached = false
var _measure_duration

var _theoric_duration
var _actual_duration

var _ending_points


func check_loop() -> bool:
	_cache()
	
	if not main_loop_stream or not main_loop_stream.has_loop():
		print("No main loop")
		return false
	
	if final_stream and final_stream.has_loop():
		print("Final is looped")
		return false
	
	if end_mode == EndMode.Final and not final_stream:
		print("No final. Changing end mode to fede out.")
		end_mode = EndMode.FedeOut
	
	if breaking_mode != BreakingMode.EveryNMeasures:
		return true
	
	var length_diff = _actual_duration - _theoric_duration
	var length_gap = abs(length_diff)
	
	var sample_diff = length_gap * 44100.0
	
	var perfect = sample_diff < 0.1
	
	var actual_greater = _actual_duration > _theoric_duration
	var word = "excess" if actual_greater else "less"
	
	if length_gap > 0.00001:
		var first_word = "Bad" if length_gap > 0.000001 else "Inexact"
		
		print("%s song length: %.12f != %.12f" % [first_word, _actual_duration, _theoric_duration])
		
		print("%.12f seconds %s" % [length_gap, word])
		print("%.12f samples %s" % [length_gap * 44100.0, word])
		
		return false
		
	elif not perfect:
		print("Pretty good: %.15f" % [length_diff])
		print("Estimated %.12f samples %s" % [sample_diff, word])
		
		return true
		
	else:
		#print("Perfect")
		return true
	

func get_total_duration() -> float:
	if not _cached:
		_cache()
	
	return _actual_duration
	
func get_measure_duration() -> float:
	if not _cached:
		_cache()
	
	return _measure_duration

func get_ending_points() -> Array:
	if not _cached:
		_cache()
	
	return _ending_points
	
func get_next_ending_point(starting_at: float) -> float:
	if starting_at < 0:
		print("Unexpected 1")
		starting_at = 0
	
	while starting_at >= _actual_duration:
		print("Unexpected 2")
		starting_at -= _actual_duration
	
	match breaking_mode:
		BreakingMode.End:
			return 0.0
		
		BreakingMode.Immediate:
			return starting_at
		
		BreakingMode.EveryNMeasures:
			if breaking_measures <= 0 or breaking_measures > number_of_measures:
				print("Invalid breaking measures %d/%d" % [breaking_measures, number_of_measures])
				return starting_at

			var step: float = breaking_measures * get_measure_duration()
			
			var ret = 0.0
			
			while ret < starting_at:
				ret += step
			
			if ret > _actual_duration:
				print("Sucedio")
				ret -= _actual_duration
				assert(not ret > _actual_duration)
			
			return ret
		
		_:
			print("Unrecognized breaking_mode %s" % BreakingMode.keys()[breaking_mode])
			return starting_at

func _cache():
	_cached = true
	
	if breaking_mode == BreakingMode.EveryNMeasures:
		_measure_duration = float(measure_numerator) / float(measure_denominator)
		_theoric_duration = _measure_duration * number_of_measures
		
	_actual_duration = main_loop_stream.get_length()
	
