extends Node

@export var tent_scene: PackedScene

# Reference to the global container
@onready var tents_container = get_node(Global.TENTS_CONTAINER_PATH)

# Dictionary to track { player_id: tent_node }
var active_tents = {}

var save_timer: float = 0.0

func _process(delta: float):
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server(): return
	save_timer += delta
	if save_timer >= 10.0:
		save_timer = 0.0
		for player_id in active_tents.keys():
			save_tent_for_player(player_id, false)

func spawn_tent_for_player(player_id: int):
	print("--- TENT DEBUG START (Player: ", player_id, ") ---")
	
	if not multiplayer.is_server(): 
		print("DEBUG: Not the server, aborting.")
		return
	
	var level_container = get_node_or_null(Global.LEVEL_PATH)
	if level_container == null:
		print("DEBUG ERROR: /root/Main/LevelLoaded does not exist!")
		return
	
	if level_container.get_child_count() == 0:
		print("DEBUG ERROR: LevelLoaded has NO children (Level not loaded yet).")
		return
		
	var current_level = level_container.get_child(0)
	print("DEBUG: Searching inside level: ", current_level.name)
	
	# Check the path strictly: Markers/TentSpawnMarkers
	var markers_folder = current_level.get_node_or_null(Global.TENT_MARKERS_LEVEL_PATH)
	if markers_folder == null:
		print("DEBUG ERROR: Could not find 'Markers/TentSpawnMarkers' inside ", current_level.name)
		# PRINT THE ACTUAL CHILDREN TO HELP US FIND THE RIGHT PATH
		print("DEBUG: Available children in level: ", current_level.get_children())
		return
	
	var all_markers = markers_folder.get_children()
	if all_markers.is_empty():
		print("DEBUG ERROR: Markers folder is empty!")
		return
		
	# Pick marker based on current tent count
	var spawn_index = active_tents.size()
	if spawn_index >= all_markers.size():
		print("DEBUG ERROR: No markers left for index: ", spawn_index)
		return
		
	var target_marker = all_markers[spawn_index]
	
	if not target_marker.is_inside_tree():
		await target_marker.tree_entered

	# Wait for a frame to ensure the global position is valid after entering the tree
	await get_tree().process_frame

	# Instantiate and Add
	var tent = tent_scene.instantiate()
	tent.name = "Tent_" + str(player_id)
	
	# Make sure tents_container is valid
	if tents_container == null:
		tents_container = get_node_or_null(Global.TENTS_CONTAINER_PATH)
		
	# Setting both position and rotation explicitly to ensure synchronization
	# and proper rotation application across the network before add_child.
	tent.position = target_marker.global_position
	tent.rotation = target_marker.global_rotation
	
	if tent.has_method("set_tent_owner"):
		tent.set_tent_owner(player_id)

	tents_container.add_child(tent, true)
	
	active_tents[player_id] = tent
	print("--- TENT DEBUG SUCCESS: Tent_", player_id, " spawned at ", target_marker.name, " ---")

	# Load the tent data
	load_tent_for_player(player_id)

func remove_tent(player_id: int):
	if not multiplayer.is_server(): return
	if active_tents.has(player_id):
		save_tent_for_player(player_id, true)
		active_tents[player_id].queue_free()
		active_tents.erase(player_id)

func get_save_path(player_id: int) -> String:
	var account_id = Global.peer_to_account.get(player_id, "")
	if account_id == "":
		account_id = str(player_id) # fallback
	return "user://tent_data_" + Global.sanitize_filename(account_id) + ".save"

func save_tent_for_player(player_id: int, is_disconnecting: bool):
	if not multiplayer.is_server(): return
	if not active_tents.has(player_id): return

	var tent = active_tents[player_id]
	var save_data = {
		"is_private": tent.is_private,
		"chest_inventory": [],
		"items": []
	}

	# Save chest inventory
	var storage_chest = tent.get_node_or_null("storageMarker/StorageChest")
	if storage_chest:
		save_data["chest_inventory"] = storage_chest.inventory.duplicate()

	# Save items in tent bounds
	var items_container = get_node_or_null(Global.ITEMS_CONTAINER_PATH)
	if items_container:
		var space_state = tent.get_world_3d().direct_space_state
		var query = PhysicsPointQueryParameters3D.new()
		query.collision_mask = 8 # Layer 4 (value 8) - Tent bounds
		query.collide_with_areas = true
		query.collide_with_bodies = false

		# Iterate backwards so we can safely queue_free if disconnecting
		var children = items_container.get_children()
		for i in range(children.size() - 1, -1, -1):
			var item = children[i]
			if not is_instance_valid(item) or item.is_queued_for_deletion(): continue
			if not (item is Item) or item.data_path == "": continue

			# Ensure we only save sleeping or loosely dropped items, not ones currently held
			if item.freeze and item.get_multiplayer_authority() != 1: continue

			if item.get("is_autospawned") == true: continue

			# Add an upward offset to reliably detect items resting on the floor
			query.position = item.global_position + Vector3(0, 0.5, 0)
			var results = space_state.intersect_point(query)

			var inside_this_tent = false
			for res in results:
				if res.collider is Area3D and res.collider.get_parent() == tent:
					inside_this_tent = true
					break

			if inside_this_tent:
				save_data["items"].append({
					"data_path": item.data_path,
					"pos_x": item.global_position.x,
					"pos_y": item.global_position.y,
					"pos_z": item.global_position.z,
					"rot_x": item.global_rotation.x,
					"rot_y": item.global_rotation.y,
					"rot_z": item.global_rotation.z
				})

				if is_disconnecting:
					# Clean up physical item if player leaves
					item.destroy_item.rpc()

	var file = FileAccess.open(get_save_path(player_id), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_tent_for_player(player_id: int):
	if not multiplayer.is_server(): return
	if not active_tents.has(player_id): return

	var tent = active_tents[player_id]
	var save_path = get_save_path(player_id)

	if not FileAccess.file_exists(save_path): return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file: return

	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or typeof(json) != TYPE_DICTIONARY: return

	if json.has("is_private"):
		tent.is_private = json["is_private"]
		# In case we need to sync manually to clients
		tent._update_barrier(tent.is_private)

	if json.has("chest_inventory"):
		var storage_chest = tent.get_node_or_null("storageMarker/StorageChest")
		if storage_chest:
			storage_chest.inventory = json["chest_inventory"].duplicate()

	if json.has("items"):
		var items_container = get_node_or_null(Global.ITEMS_CONTAINER_PATH)
		if items_container:
			for item_data in json["items"]:
				if typeof(item_data) != TYPE_DICTIONARY: continue
				if not item_data.has("data_path"): continue

				var res = load("res://scenes/features/baseItem.tscn")
				if not res: continue
				var new_item = res.instantiate()

				var pos = Vector3(item_data.get("pos_x", 0), item_data.get("pos_y", 0), item_data.get("pos_z", 0))
				var rot = Vector3(item_data.get("rot_x", 0), item_data.get("rot_y", 0), item_data.get("rot_z", 0))

				# Set local position and rotation before add_child to prevent multiplayer sync errors
				new_item.position = pos
				new_item.rotation = rot

				# Set data path before it enters the tree to ensure visual sync on clients right away
				new_item.data_path = item_data["data_path"]

				# Add the child without manually modifying the name. The MultiplayerSpawner will seamlessly synchronize it.
				items_container.add_child(new_item, true)

				# Yielding to ensure the item enters the tree safely
				await get_tree().process_frame
		
		
