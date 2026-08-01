class_name LoggingState
extends State
## Test-only state that records enter/exit order.

var log_ref: Array
var label: String = ""


func enter(_msg: Dictionary = {}) -> void:
	log_ref.append("%s:enter" % label)


func exit() -> void:
	log_ref.append("%s:exit" % label)
