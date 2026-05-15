extends Area3D

@onready var status_label = $Label3D # Make sure this name matches your node
@onready var liquid_mesh = $LiquidMesh
@onready var steam_particles = $GPUParticles3D
# This list will keep track of what we've thrown in
var pot_contents = []


func _on_body_entered(body: Node3D) -> void:
	# 1. Check if the object entering is actually an ingredient
	if body.is_in_group("interactables"):
		
		if "ingredient_name" in body:
			var what_is_it = body.ingredient_name
			print("Dropped in: ", what_is_it)
			pot_contents.append(what_is_it)
			body.queue_free()
			update_label()
			check_recipes()



func check_recipes():
	# Simple logic: If we have a Tomato and a Mushroom, we made Stew!
	if pot_contents.has("Tomato") and pot_contents.has("Mushroom"):
		var mat = liquid_mesh.get_active_material(0)
		mat.albedo_color = Color(0.8, 0.1, 0.1) # Tomato Red
		
		# 2. Start the steam!
		steam_particles.emitting = true
		
		status_label.text = "Cooking soup! (Mushroom Stew)"
		status_label.modulate = Color(0, 1, 0) # Turn the text green for success



func update_label():
	if pot_contents.size() == 0:
		status_label.text = "The pot is empty..."
	else:
		# This joins the list into a single string: "Tomato, Mushroom"
		var list_text = ", ".join(pot_contents)
		status_label.text = "Cooking: " + list_text
