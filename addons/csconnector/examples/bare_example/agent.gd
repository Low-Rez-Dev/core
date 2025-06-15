extends Node

signal did_something(arg)

# This is set in the context's setup_agent() method.
var count = -100


func _enter_tree():
	# The best time to register an agent is in _enter_tree().
	CSConnector.with(self).register("agents")
	do_something()


func _on_timer_timeout():
	do_something()


func do_something():
	count += 1
	if count <= 10:
		did_something.emit(name + " counted " + str(count))
	else:
		queue_free()
