class_name SymbolTable

var _types: Array # array of strings

var _symbols_by_name = {} # dict with dicts
var _symbols_by_type = {} # dict with {list, dict with symbols}

var _aliases = {}

const empty_symbol = { type = false }

func _init(symbol_types: Array):
	_types = symbol_types
	for t in _types:
		if _symbols_by_type.has(t):
			print("Duplicated type '%s'" % t)
			continue
		_symbols_by_type[t] = { list=[], dict={} }
	
func has_symbol(symbol_name: String) -> bool:
	if _aliases.has(symbol_name):
		var _has = _symbols_by_name.has(_aliases[symbol_name])
		if _has:
			return true
		else:
			print("Alias is present but no target symbol")
			return false
	
	return _symbols_by_name.has(symbol_name)

func get_symbol(symbol_name: String):
	if _aliases.has(symbol_name):
		var _has = _symbols_by_name.has(_aliases[symbol_name])
		if _has:
			return _symbols_by_name[_aliases[symbol_name]]
		else:
			print("Alias is present but no target symbol")
			return null
	
	if _symbols_by_name.has(symbol_name):
		return _symbols_by_name[symbol_name]
	else:
		return null
	
func get_symbol_type(symbol_name: String) -> String:
	var symbol = get_symbol(symbol_name)
	return symbol.type if symbol else null
	
func remove_symbol(symbol_name: String) -> bool:
	if not has_symbol(symbol_name):
		print("Can't remove symbol '%s': not present")
		return false
	
	var symbol = _symbols_by_name[symbol_name]
	_symbols_by_name.erase(symbol_name)
	
	var symbol_type = symbol.type
	var pack: Dictionary = _get_pack(symbol_type)
	
	var list: Array = pack.list
	var dict: Dictionary = pack.dict
	
	assert(dict.has(symbol_name) and dict[symbol_name] == symbol)
	if not dict.erase(symbol_name):
		print("Error loco")
	
	assert(list[symbol.index] == symbol)
	list.remove(symbol.index)
	
	for j in range(symbol.index, list.size()):
		var k = list[j].index
		assert(k == j + 1)
		list[j].index -= 1
	
	return true
	
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

func has_alias(alias_name: String) -> bool:
	return _aliases.has(alias_name)
	
func set_alias(alias_name: String, target_symbol_name: String):
	_aliases[alias_name] = target_symbol_name

func remove_alias(alias_name: String):
	_aliases.erase(alias_name)


# If there's a type mismatch, returns { type=false } (meaning invalid result)
# If it's absent, returns the same if required=true or null if it's not required (meaning absent)
func get_symbol_of_types(symbol_name:String, types: Array, required: bool):
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
