extends Node

@export var house_scene: PackedScene
@export var entrance_scene: PackedScene

# Reference to the global container
@onready var houses_container = get_node_or_null(Global.HOUSES_CONTAINER_PATH)
@onready var entrances_container = get_node_or_null(Global.HOUSE_ENTRANCES_CONTAINER_PATH)

# Dictionary to track { player_id: house_node }
var active_houses = {}
var active_entrances = {}

var save_timer: float = 0.0

func _process(delta: float):
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server(): return
	save_timer += delta
	if save_timer >= 10.0:
		save_timer = 0.0
		for player_id in active_houses.keys():
			save_house_for_player(player_id, false)

func spawn_house_for_player(player_id: int):
	print("--- HOUSE DEBUG START (Player: ", player_id, ") ---")

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

	# Get House Spawn Markers
	var house_markers_folder = current_level.get_node_or_null(Global.HOUSE_MARKERS_LEVEL_PATH)
	if house_markers_folder == null:
		print("DEBUG ERROR: Could not find house markers inside ", current_level.name)
		return
	var house_markers = house_markers_folder.get_children()

	# Get Entrance Spawn Markers
	var entrance_markers_folder = current_level.get_node_or_null(Global.HOUSE_ENTER_MARKERS_LEVEL_PATH)
	if entrance_markers_folder == null:
		print("DEBUG ERROR: Could not find house entrance markers inside ", current_level.name)
		return
	var entrance_markers = entrance_markers_folder.get_children()

	if house_markers.is_empty() or entrance_markers.is_empty():
		print("DEBUG ERROR: Markers folders are empty!")
		return

	# Find an available marker index
	var spawn_index = -1
	for i in range(house_markers.size()):
		var is_used = false
		for house in active_houses.values():
			if house.global_position.is_equal_approx(house_markers[i].global_position):
				is_used = true
				break
		if not is_used:
			spawn_index = i
			break

	if spawn_index == -1 or spawn_index >= entrance_markers.size():
		print("DEBUG ERROR: No markers left or available for index: ", spawn_index)
		return

	var target_house_marker = house_markers[spawn_index]
	var target_entrance_marker = entrance_markers[spawn_index]

	if not target_house_marker.is_inside_tree() or not target_entrance_marker.is_inside_tree():
		await target_house_marker.tree_entered

	# Wait for a frame to ensure the global position is valid after entering the tree
	await get_tree().process_frame

	# Instantiate and Add House
	var house = house_scene.instantiate()
	house.name = "House_" + str(player_id)

	if houses_container == null:
		houses_container = get_node_or_null(Global.HOUSES_CONTAINER_PATH)

	house.position = target_house_marker.global_position
	house.rotation = target_house_marker.global_rotation
	houses_container.add_child(house, true)

	# Instantiate and Add Entrance
	var entrance = entrance_scene.instantiate()
	entrance.name = "HouseEntrance_" + str(player_id)

	if entrances_container == null:
		entrances_container = get_node_or_null(Global.HOUSE_ENTRANCES_CONTAINER_PATH)

	entrance.position = target_entrance_marker.global_position
	entrance.rotation = target_entrance_marker.global_rotation
	entrances_container.add_child(entrance, true)

	# Set references so they know about each other
	if house.has_method("set_house_owner"):
		house.set_house_owner(player_id, entrance)

	if entrance.has_method("set_entrance_owner"):
		entrance.set_entrance_owner(player_id, house)

	active_houses[player_id] = house
	active_entrances[player_id] = entrance
	print("--- HOUSE DEBUG SUCCESS: House_", player_id, " spawned ---")

	# Load the house data
	load_house_for_player(player_id)

func remove_house(player_id: int):
	if not multiplayer.is_server(): return
	if active_houses.has(player_id):
		save_house_for_player(player_id, true)
		active_houses[player_id].queue_free()
		active_houses.erase(player_id)
	if active_entrances.has(player_id):
		active_entrances[player_id].queue_free()
		active_entrances.erase(player_id)

func get_save_path(player_id: int) -> String:
	var account_id = Global.peer_to_account.get(player_id, "")
	if account_id == "":
		account_id = str(player_id) # fallback
	return "user://house_data_" + Global.sanitize_filename(account_id) + ".save"

func save_house_for_player(player_id: int, is_disconnecting: bool):
	if not multiplayer.is_server(): return
	if not active_houses.has(player_id): return

	var house = active_houses[player_id]
	var save_data = {
		"items": []
	}

	# Save items in house bounds
	var items_container = get_node_or_null(Global.ITEMS_CONTAINER_PATH)
	if items_container:
		var space_state = house.get_world_3d().direct_space_state
		var query = PhysicsPointQueryParameters3D.new()
		query.collision_mask = 8 # Layer 4 (value 8) - House/Tent bounds
		query.collide_with_areas = true
		query.collide_with_bodies = false

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

			var inside_this_house = false
			for res in results:
				if res.collider is Area3D and res.collider.get_parent() == house:
					inside_this_house = true
					break

			if inside_this_house:
				var local_transform = house.global_transform.affine_inverse() * item.global_transform
				save_data["items"].append({
					"data_path": item.data_path,
					"pos_x": local_transform.origin.x,
					"pos_y": local_transform.origin.y,
					"pos_z": local_transform.origin.z,
					"rot_x": local_transform.basis.get_euler().x,
					"rot_y": local_transform.basis.get_euler().y,
					"rot_z": local_transform.basis.get_euler().z
				})

				if is_disconnecting:
					item.destroy_item.rpc()

	var file = FileAccess.open(get_save_path(player_id), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_house_for_player(player_id: int):
	if not multiplayer.is_server(): return
	if not active_houses.has(player_id): return

	var house = active_houses[player_id]
	var save_path = get_save_path(player_id)

	if not FileAccess.file_exists(save_path): return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file: return

	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or typeof(json) != TYPE_DICTIONARY: return

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

				var local_transform = Transform3D(Basis.from_euler(rot), pos)
				var global_tf = house.global_transform * local_transform

				new_item.global_transform = global_tf
				new_item.data_path = item_data["data_path"]

				items_container.add_child(new_item, true)
				await get_tree().process_frame
