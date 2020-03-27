class_name SymbolTable

var _types: Array # array of strings

var _symbols_by_name = {} # dict with dicts
var _symbols_by_type = {} # dict with {list, dict with symbols}

const empty_symbol = { type = false }

func _init(symbol_types: Array):
	_types = symbol_types
	for t in _types:
		if _symbols_by_type.has(t):
			print("Duplicated type '%s'" % t)
			continue
		_symbols_by_type[t] = { list=[], dict={} }
	
func has_symbol(symbol_name: String) -> bool:
	return _symbols_by_name.has(symbol_name)

func get_symbol(symbol_name: String):
	if not has_symbol(symbol_name):
		return null
	return _symbols_by_name[symbol_name]
	
func get_symbol_type(symbol_name: String) -> String:
	if not has_symbol(symbol_name):
		return ""
	return _symbols_by_name[symbol_name].type
	
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

# If there's a type mismatch, returns { type=false } (meaning invalid result)
# If it's absent, returns the same if required=true or null if it's not required (meaning absent)
func get_symbol_of_types(symbol_name:String, types: Array, required: bool):
	if not _symbols_by_name.has(symbol_name):
		if required:
			print("SymbolTable: no symbol '%s' in %s" % [symbol_name, types])
			return empty_symbol
		else:
			return null
	
	var symbol = _symbols_by_name[symbol_name]
	
	if symbol.type in types:
		return symbol
	else:
		print("SymbolTable: type of '%s' is %s, not in %s" % [symbol_name, symbol.type, types])
		return empty_symbol
	
func _get_pack(symbol_type: String):
	if not _symbols_by_type.has(symbol_type):
		print("No symbol type '%s'!" % symbol_type)
	
	return _symbols_by_type[symbol_type]
