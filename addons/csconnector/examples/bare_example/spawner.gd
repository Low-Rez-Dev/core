extends Node

var Agent = preload("agent.tscn")


func _on_timer_timeout():
	if get_child_count() < 5:
		var agent = Agent.instantiate()
		add_child(agent)
