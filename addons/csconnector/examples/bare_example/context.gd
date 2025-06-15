# This context node uses CSConnector to set up agents and respond to their
# signals with minimal setup, not caring about where exactly they are below
# it in the scene tree, or about when their _enter_tree() and _ready()
# methods are called relative to its own _enter_tree() and _ready() methods.
# This demonstrates the structural and temporal flexibility that
# CSConnector provides.

extends Node

var agent_number = 0


# setup_agent() is called with the initial agent after its _ready() method
# and is called on spawned agents before their _ready() methods, but the result
# is the same either way. This demonstrates how context and agent can flexibly
# begin their connection in any order.
# Try changing this to use _enter_tree() to catch the initial agent's first
# count in its _enter_tree() method and not break anything in the process.
#func _enter_tree():
func _ready():
	CSConnector.with(self).connect_signal("agents", "did_something", respond_to_something)
	CSConnector.with(self).connect_setup("agents", setup_agent)


func setup_agent(agent):
	agent_number += 1
	agent.name = "Agent" + str(agent_number)
	agent.count = 0


func respond_to_something(arg):
	print(arg)
