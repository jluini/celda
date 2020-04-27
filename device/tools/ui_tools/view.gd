"""
	Class: View
	A Node that reflects the state of a target object.

	Copyright:
	Copyright 2020, jluini
"""

extends Node

var target = null # setget set_target, get_target

# TODO remove this or extract to superclass
var index = -1

#	@PUBLIC
"""
"""
func set_target(new_target): # new_index, new_target):
	target_changing(target, new_target)
	target = new_target
	#index = new_index

"""
"""
func get_target():
	return target


#	@PRIVATE

"""
	Private Function: target_changing

	Called when target has changed.
	Must be overriden by subclasses.
	
	@param _old_target The previous target or null
	@param _new_target The new target
"""
func target_changing(_old_target, _new_target):
	pass

