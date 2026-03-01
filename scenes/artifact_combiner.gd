extends Node3D

@export var recipes: Array[ArtifactData] = []
@export var spawn_point: Marker3D
@export var item_scene: PackedScene # Your base "Item.tscn" that can hold ItemData

var items_in_zone: Array[Node3D] = []

@export var vfx_scene: PackedScene



func check_for_combination():
	if recipes.is_empty():
		print("Combiner: No recipes assigned!")
		return
	
	items_in_zone = items_in_zone.filter(func(item): return is_instance_valid(item))
	
	var current_parts_data = []
	for item in items_in_zone:
		var d = item.get("data")
		if d != null:
			current_parts_data.append(d)
	
	# 2. Compare against our recipes
	for recipe in recipes:
		if recipe == null: 
			continue
		if _matches_recipe(recipe, current_parts_data):
			_combine(recipe)
			return # Stop after one successful combination

func _matches_recipe(recipe: ArtifactData, current_parts: Array) -> bool:
	
	print("Checking recipe: ", recipe.recipe_name)
	print("Required: ", recipe.required_parts.size(), " | Current: ", current_parts.size())
	if recipe.required_parts == null or recipe.required_parts.is_empty():
		return false
		
	# If we don't even have enough items, don't bother checking
	if current_parts.size() < recipe.required_parts.size():
		return false
	
	# We need to make sure EVERY required part is present in the pile
	var temp_required = recipe.required_parts.duplicate()
	
	for part_data in current_parts:
		print("Comparing item on table: ", part_data.resource_path, " with recipe requirements...")
		if temp_required.has(part_data):
			temp_required.erase(part_data)
			print("Match found!")
	
	# If the list is empty, we found all the pieces!
	return temp_required.is_empty()

func _combine(recipe: ArtifactData):
	print("COMBINER: Creating ", recipe.recipe_name)
	
	# 1. Identify which nodes to delete (only the ones used in the recipe)
	var used_nodes = []
	var temp_required = recipe.required_parts.duplicate()
	
	for item in items_in_zone:
		if "data" in item and temp_required.has(item.data):
			used_nodes.append(item)
			temp_required.erase(item.data)
	
	# 2. Delete the parts (Server deletes, Spawner/Networking handles clients)
	for node in used_nodes:
		items_in_zone.erase(node)
		node.queue_free()
	
	# 3. Spawn the Result
	# We spawn your base 'item_scene' and give it the 'result_item' data
	var result_node = item_scene.instantiate()
	get_parent().add_child(result_node, true)
	result_node.global_position = spawn_point.global_position
	
	# Inject the data into the new node
	if "data" in result_node:
		result_node.data = recipe.result_item
		# If your Item script has a function to refresh its mesh/color based on data:
		if result_node.has_method("update_from_data"):
			result_node.update_from_data()

	# 4. Optional: Play a "Success" RPC for VFX/Sound
	# play_craft_vfx.rpc(spawn_point.global_position)


func _on_detection_area_body_entered(body: Node3D) -> void:
	print("Combiner touched: ", body.name, " (Type: ", body.get_class(), ")")
	print("Nodes Groups: ", body.get_groups())
	if not multiplayer.is_server(): return
	
	
	if body.is_in_group("interactables"):
		if not items_in_zone.has(body):
			items_in_zone.append(body)
			# DEBUG 2: Did it pass the group check?
			print("Combiner: Item added to list. Total items: ", items_in_zone.size())
			check_for_combination()
	else:
		print("Combiner: Entered body is NOT in 'interactables' group!")
	
	if body.is_in_group("interactables") and not items_in_zone.has(body):
		items_in_zone.append(body)
		# Every time a new item is dropped, check if we can build something
		check_for_combination()
	


func _on_detection_area_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if items_in_zone.has(body):
		items_in_zone.erase(body)


func _spawn_local_vfx(pos: Vector3, color: Color):
	if vfx_scene == null:
		return
		
	var vfx = vfx_scene.instantiate()
	# Add to the world first so it's 'inside the tree'
	get_tree().root.add_child(vfx)
	
	# Now set the position using the Vector3 we passed in
	vfx.global_position = pos
	vfx.color = color
	
	if vfx.has_method("restart"):
		vfx.restart()
	

@rpc("authority", "call_remote", "unreliable") # "call_remote" skips the sender!
func _spawn_vfx_for_others(pos: Vector3, color: Color):
	_spawn_local_vfx(pos, color)
