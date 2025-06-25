# Test script to verify save/load template functionality
# This script can be run in the Redot editor to test the template system

extends Node

func _ready():
	print("Testing Entity Template Save/Load System...")
	test_template_system()

func test_template_system():
	# Create a mock entity editor to test the functionality
	var editor = load("res://scripts/EntityEditor.gd").new()
	
	# Test 1: Create a simple body part
	var test_part = BodyPart.new()
	test_part.part_name = "Test_Torso"
	test_part.polygon_points = PackedVector2Array([
		Vector2(-60, -80),
		Vector2(60, -80),
		Vector2(60, 80),
		Vector2(-60, 80)
	])
	test_part.attachment_point = Vector2(0, -80)  # Top attachment
	test_part.parent_attachment = Vector2(0, 80)  # Bottom attachment
	
	# Add a layer
	var skin_layer = LayerData.new()
	skin_layer.material_type = "skin"
	skin_layer.thickness = 0.5
	skin_layer.quality = 0.8
	test_part.layers["skin"] = skin_layer
	
	# Add to editor's body parts
	editor.body_parts = [test_part]
	
	# Test 2: Save the template
	print("Saving test template...")
	editor.save_current_template("Test_Entity")
	
	# Test 3: Load the template
	print("Loading test template...")
	editor.load_template("Test_Entity")
	
	# Test 4: Verify the data
	if editor.body_parts.size() > 0:
		var loaded_part = editor.body_parts[0]
		print("✅ Template loaded successfully!")
		print("  Part name: ", loaded_part.part_name)
		print("  Polygon points: ", loaded_part.polygon_points.size())
		print("  Has skin layer: ", loaded_part.layers.has("skin"))
		if loaded_part.layers.has("skin"):
			var layer = loaded_part.layers["skin"]
			print("  Skin material: ", layer.material_type)
			print("  Skin thickness: ", layer.thickness)
	else:
		print("❌ Template load failed!")
	
	# Test 5: List available templates
	print("Available templates:")
	var templates = editor.get_available_templates()
	for template in templates:
		print("  - ", template)
	
	print("Template system test complete!")