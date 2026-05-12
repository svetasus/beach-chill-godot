extends Node3D

@export var recipe_list: ArtifactRecipeList
signal items_changed()
@export var spawn_point: Marker3D
@export var item_scene: PackedScene 
@export var vfx_scene: PackedScene


var items_container: Node3D

var items_in_zone: Array[Node3D] = []


func _ready():
	items_container = get_node_or_null(Global.ITEMS_CONTAINER_PATH)

# --- 1. DETECTION LOGIC (SERVER ONLY) ---

func _on_detection_area_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	
	if body.is_in_group("interactables") and not items_in_zone.has(body):
		items_in_zone.append(body)
		items_changed.emit()
		check_for_combination()

func _on_detection_area_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if items_in_zone.has(body):
		items_in_zone.erase(body)
		items_changed.emit()

# --- 2. MATCHING LOGIC (THE BRAIN) ---

func check_for_combination():

	# Server double-check
	if not multiplayer.is_server(): return
	
	# Clean up any nodes that might have been freed while in the zone
	items_in_zone = items_in_zone.filter(func(item): return is_instance_valid(item))
	
	# Get the data from all items currently sitting on the table
	var current_parts_data = []
	for item in items_in_zone:
		var d = item.get("data")
		if d != null:
			current_parts_data.append(d)
	
	if recipe_list == null: return
	for recipe in recipe_list.recipes:
		if recipe == null: continue
		if _matches_recipe(recipe, current_parts_data):
			_combine(recipe)
			return # Stop after one successful craft

func _matches_recipe(recipe: ArtifactData, current_parts: Array) -> bool:
	# If we have fewer items than required, it's impossible
	if current_parts.size() < recipe.required_parts.size():
		return false
	
	# We use a copy of the requirements to "check them off"
	var temp_required = recipe.required_parts.duplicate()
	
	for part_data in current_parts:
		# Does this recipe need this specific piece of data?
		if temp_required.has(part_data):
			temp_required.erase(part_data)
	
	# If the list is empty, we found a perfect match!
	return temp_required.is_empty()

# --- 3. COMBINING & SYNCING ---

func _combine(recipe: ArtifactData):
	if not multiplayer.is_server(): return
	print("SERVER: Crafting ", recipe.recipe_name)
	
	# Identify the specific nodes to remove
	var used_nodes = []
	var crafter_id = 1
	var temp_required = recipe.required_parts.duplicate()
	
	for item in items_in_zone:
		if is_instance_valid(item) and item.get("data") in temp_required:
			used_nodes.append(item)
			crafter_id = item.get_multiplayer_authority()
			temp_required.erase(item.data)
	
	# Delete ingredients
	for node in used_nodes:
		if node.has_method("destroy_item"):
			node.destroy_item.rpc()
		else:
			node.queue_free() # Fallback
		
		items_in_zone.erase(node)
	
	# Instantiate result with a unique network name
	var result_node = item_scene.instantiate()
	result_node.name = "Artifact_" + str(Time.get_ticks_msec())
	
	
	# Add to level (Must be in MultiplayerSpawner path!)
	var spawn_folder = items_container
	spawn_folder.add_child(result_node, true)
	#get_parent().add_child(result_node, true)
	result_node.global_position = spawn_point.global_position
	
	#result_node.scale = Vector3.ZERO # Start invisible/tiny
	#var tween = get_tree().create_tween()
	#tween.tween_property(result_node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await get_tree().process_frame
	if is_instance_valid(result_node):
		result_node.data_path = recipe.result_item.resource_path
	

	# Inject Data (Synchronizer must replicate 'data' variable!)
	if "data" in result_node:
		result_node.data = recipe.result_item
		if result_node.has_method("update_from_data"):
			result_node.update_from_data()

	# Add to collection
	var player_node = get_tree().root.find_child(str(crafter_id), true, false)
	if player_node and player_node.has_method("add_to_artifacts_crafted_rpc"):
		player_node.rpc_id(crafter_id, "add_to_artifacts_crafted_rpc", recipe.result_item.resource_path)
