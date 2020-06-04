extends Object

# TODO add documentation
# remark it must be manually freed

class_name SymbolTable

var _types: Array # array of strings

var _symbols_by_name = {} # dict with dicts
var _symbols_by_type = {} # dict with {list, dict with symbols}

var _context = {}

const empty_symbol = { type = false }

func _init(symbol_types: Array):
	_types = symbol_types
	for t in _types:
		if _symbols_by_type.has(t):
			print("Duplicated type '%s'" % t)
			continue
		_symbols_by_type[t] = { list=[], dict={} }
	
func has_symbol(symbol_name: String) -> bool:
	return get_symbol(symbol_name) != null

func get_symbol(symbol_name: String):
	if _context.has(symbol_name):
		var target_symbol_name: String = _context[symbol_name]
		var symbol_is_present = _symbols_by_name.has(target_symbol_name)

		if symbol_is_present:
			return _symbols_by_name[target_symbol_name]
		else:
			push_error("context string '%s' is present but target symbol '%s' is not" % [symbol_name, target_symbol_name])
			return null
		
	if _symbols_by_name.has(symbol_name):
		return _symbols_by_name[symbol_name]
	else:
		return null
	
func get_symbol_type(symbol_name: String) -> String:
	var symbol = get_symbol(symbol_name)
	return symbol.type if symbol else null

#func remove_symbol(symbol_name: String) -> bool:
#	if not has_symbol(symbol_name):
#		print("Can't remove symbol '%s': not present")
#		return false
#
#	var symbol = _symbols_by_name[symbol_name]
#	_symbols_by_name.erase(symbol_name)
#
#	var symbol_type = symbol.type
#	var pack: Dictionary = _get_pack(symbol_type)
#
#	var list: Array = pack.list
#	var dict: Dictionary = pack.dict
#
#	assert(dict.has(symbol_name) and dict[symbol_name] == symbol)
#	if not dict.erase(symbol_name):
#		print("Error loco")
#
#	assert(list[symbol.index] == symbol)
#	list.remove(symbol.index)
#
#	for j in range(symbol.index, list.size()):
#		var k = list[j].index
#		assert(k == j + 1)
#		list[j].index -= 1
#
#	return true

func add_symbol(symbol_name: String, symbol_type: String, target) -> Dictionary:
	if _symbols_by_name.has(symbol_name):
		print("SymbolTable::add_symbol: Already has symbol '%s'" % symbol_name)
		return empty_symbol
	
	var pack = _get_pack(symbol_type)
	
	var symbol = {
		type = symbol_type,
		symbol_name = symbol_name,
		index = pack.list.size(),
		target = target
	}
	
	_symbols_by_name[symbol_name] = symbol
	
	pack.list.append(symbol)
	
	assert(not pack.dict.has(symbol_name))
	pack.dict[symbol_name] = symbol
	
	return symbol

func set_context(new_context: Dictionary) -> void:
	_context = new_context
	
	for key in new_context:
		if typeof(key) != TYPE_STRING:
			push_error("context keys must be strings")
			continue
		
		if typeof(new_context[key]) != TYPE_STRING:
			push_error("context values must be strings")
			continue
		
		var target_symbol_name: String = new_context[key]
		
		if not _symbols_by_name.has(target_symbol_name):
			push_error("symbol '%s' referenced by context string '%s' is absent" % [target_symbol_name, key])
			continue

func get_context() -> Dictionary:
	return _context

# If there's a type mismatch, returns { type=false } (meaning invalid result)
# If it's absent, returns the same if required=true or null if it's not required (meaning absent)
func get_symbol_of_types(symbol_name: String, types: Array, required: bool):
	var symbol = get_symbol(symbol_name)
	
	if not symbol:
		if required:
			print("SymbolTable: no symbol '%s' in %s" % [symbol_name, types])
			return empty_symbol
		else:
			return null
	
	if symbol.type in types:
		return symbol
	else:
		print("SymbolTable: type of '%s' is %s, not in %s" % [symbol_name, symbol.type, types])
		return empty_symbol
	
func _get_pack(symbol_type: String):
	if not _symbols_by_type.has(symbol_type):
		print("No symbol type '%s'!" % symbol_type)
	
	return _symbols_by_type[symbol_type]
