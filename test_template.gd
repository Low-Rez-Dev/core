# Quick test script to manually verify template functionality
# Add this as a script to a Node in the scene to test

extends Node

@onready var entity_editor = get_node("../EntityEditor")

func _ready():
	print("Template test script ready. Use _test_save_load() function.")

func _test_save_load():
	if not entity_editor:
		print("EntityEditor not found!")
		return
	
	# Check if we have any parts to save
	if entity_editor.body_parts.size() == 0:
		print("No body parts to save. Create a part first!")
		return
	
	print("Testing save/load with ", entity_editor.body_parts.size(), " parts...")
	
	# Save current entity
	entity_editor.save_current_template("Manual_Test")
	print("Saved template 'Manual_Test'")
	
	# List templates
	var templates = entity_editor.get_available_templates()
	print("Available templates: ", templates)
	
	# Clear and reload
	var original_count = entity_editor.body_parts.size()
	entity_editor.clear_current_entity()
	print("Cleared entity (had ", original_count, " parts)")
	
	# Load the template
	entity_editor.load_template("Manual_Test")
	print("Loaded template. Now has ", entity_editor.body_parts.size(), " parts")
	
	if entity_editor.body_parts.size() == original_count:
		print("✅ Save/Load test PASSED!")
	else:
		print("❌ Save/Load test FAILED!")