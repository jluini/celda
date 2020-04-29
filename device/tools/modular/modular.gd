extends Control

#export (Array, Theme) var themes
#export (int) var current_theme

var _modules: Array
var _broadcast_listeners = {}

func _ready():
	_modules = _get_modules()
	
	var valid = true
	
	for index in range(_modules.size()):
		var module: Control = _modules[index]
		var name = module.get_name()
		
		_log("initializing '%s'" % name)
		
		var result = module.initialize(self)
		
		if not result.valid:
			valid = false
			_log_error("error initializing '%s'" % name, 1)
			_log_error(result.message)
			break
		
		var ls = module.get_signals()
		
		for l in ls:
			var key = _signal_key(l.category, l.signal_name)
			
			if not _broadcast_listeners.has(key):
				_broadcast_listeners[key] = []
			
			_broadcast_listeners[key].append({
				target = l.target,
				method_name = l.method_name
			})
		
		if index != _modules.size() - 1:
			module.hide()
		
	
	if _modules.size() == 0:
		_log("No modules")
	else:
		if valid:
			_log("%s modules initialized successfully" % _modules.size())


func change_theme(new_theme: Theme):
	set_theme(new_theme)


# Local logging shortcuts

func _log(message: String, level = 0):
	log_info("modular", message, level)
func _log_error(message: String, level = 0):
	log_error("modular", message, level)


# General logging

enum Severity {
	Info,
	Warning,
	Error
}
	
func log_info(category: String, message: String, level = 0):
	log_message(Severity.Info, category, message, level)
func log_warning(category: String, message: String, level = 0):
	log_message(Severity.Warning, category, message, level)
func log_error(category: String, message: String, level = 0):
	log_message(Severity.Error, category, message, level)
	
	
func log_message(severity: int, category: String, message: String, _level = 0):
	printt(_severity_str(severity), "%-10s" % category, message)

func _severity_str(severity: int) -> String:
	var severities = Severity.keys()
	if severity >= 0 and severity < severities.size():
		return severities[severity]
	else:
		return "?%s?" % severity
	

func _get_modules():
	return $ui/modules.get_children()
	
func broadcast(category: String, signal_name: String, args: Array):
	var key = _signal_key(category, signal_name)
	
	if _broadcast_listeners.has(key):
		var listeners = _broadcast_listeners[key]
		for l in listeners:
			var obj: Object = l.target
			var method_name: String = l.method_name
			
			obj.callv(method_name, args)

func _signal_key(category: String, signal_name: String) -> String:
	return "%s:%s" % [category, signal_name]

func _on_quit_button_pressed():
	get_tree().quit()
