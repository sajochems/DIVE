extends Node


signal log_added(text: String)

func log(text: String):
	print(text) 
	log_added.emit(text)

func warn(text: String):
	push_warning(text)
	log_added.emit("[WARN] " + text)

func err(text: String):
	push_error(text)
	log_added.emit("[ERROR] " + text)
