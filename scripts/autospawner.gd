extends Node

var _spawned_nodes: Array[Node] = []

func trigger_spawn():
	if not multiplayer.is_server():
		return

	var level = get_node_or_null(Global.LEVEL_PATH)
	if not level:
		print("AutoSpawner: No level loaded at ", Global.LEVEL_PATH)
		return

	var autospawn_areas = _find_node_by_name_recursive(level, "AutospawnAreas")
	if not autospawn_areas:
		print("AutoSpawner: No 'AutospawnAreas' node found in level.")
		return

	for area in autospawn_areas.get_children():
		if area is AutospawnArea:
			_spawn_in_area(area)

func _find_node_by_name_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name_recursive(child, target_name)
		if found:
			return found
	return null

func _spawn_in_area(area: AutospawnArea):
	if not area.get_child_count() > 0:
		return

	var collision_shape = null
	for child in area.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			collision_shape = child
			break

	if not collision_shape:
		print("AutoSpawner: Area ", area.name, " needs a BoxShape3D CollisionShape3D child.")
		return

	var box: BoxShape3D = collision_shape.shape
	var extents = box.size / 2.0

	# Spawn Items
	if area.spawn_profile and area.spawn_profile.items.size() > 0 and area.item_scene:
		for i in range(area.max_items):
			var local_pos = Vector3(
				randf_range(-extents.x, extents.x),
				extents.y, # Start raycast from top of the box
				randf_range(-extents.z, extents.z)
			)
			var global_pos = collision_shape.global_transform * local_pos

			var ground_pos = _get_ground_position(global_pos, 100.0) # Using a large fixed distance to guarantee floor hit
			if ground_pos != Vector3.ZERO:
				var item_data = area.spawn_profile.items.pick_random()
				_spawn_item(area.item_scene, item_data, ground_pos)

	# Spawn Treasures
	if area.treasure_profile and area.treasure_profile.loot_table.size() > 0 and area.treasure_profile.treasure_scene:
		for i in range(area.max_treasures):
			var local_pos = Vector3(
				randf_range(-extents.x, extents.x),
				extents.y, # Start raycast from top of the box
				randf_range(-extents.z, extents.z)
			)
			var global_pos = collision_shape.global_transform * local_pos

			var ground_pos = _get_ground_position(global_pos, 100.0) # Using a large fixed distance to guarantee floor hit
			if ground_pos != Vector3.ZERO:
				_spawn_treasure(area.treasure_profile, ground_pos)

func _get_ground_position(start_pos: Vector3, ray_length: float) -> Vector3:
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_pos, start_pos + Vector3.DOWN * ray_length, 1) # Layer 1
	var result = space_state.intersect_ray(query)

	if result:
		return result.position + Vector3(0, 0.5, 0)
	return Vector3.ZERO

func _spawn_item(item_scene: PackedScene, item_data: ItemData, pos: Vector3):
	var item_instance = item_scene.instantiate()
	item_instance.name = "AutoSpawnedItem_" + str(Time.get_ticks_usec())

	var container = get_node_or_null(Global.ITEMS_CONTAINER_PATH)
	if not container:
		container = get_tree().root.get_node_or_null(Global.ITEMS_CONTAINER_PATH)

	if container:
		container.add_child(item_instance, true)
	else:
		print("AutoSpawner: Could not find ItemsContainer at %s" % Global.ITEMS_CONTAINER_PATH)
		get_parent().add_child(item_instance, true)

	item_instance.global_position = pos

	if "data_path" in item_instance:
		item_instance.data_path = item_data.resource_path
	elif "data" in item_instance:
		item_instance.data = item_data

	_spawned_nodes.append(item_instance)

func _spawn_treasure(profile: TreasureProfile, pos: Vector3):
	var treasure_instance = profile.treasure_scene.instantiate()
	treasure_instance.name = "AutoSpawnedTreasure_" + str(Time.get_ticks_usec())

	var container = get_node_or_null(Global.TREASURES_CONTAINER_PATH)
	if not container:
		container = get_tree().root.get_node_or_null(Global.TREASURES_CONTAINER_PATH)

	if container:
		container.add_child(treasure_instance, true)
	else:
		print("AutoSpawner: Could not find TreasuresContainer at %s" % Global.TREASURES_CONTAINER_PATH)
		get_parent().add_child(treasure_instance, true)

	if not treasure_instance.is_in_group("treasures"):
		treasure_instance.add_to_group("treasures")

	treasure_instance.global_position = pos

	if "loot_table" in treasure_instance:
		treasure_instance.loot_table = profile.loot_table
	if "base_item_scene" in treasure_instance:
		treasure_instance.base_item_scene = profile.base_item_scene
	if "sand_particles" in treasure_instance:
		treasure_instance.sand_particles = profile.sand_particles

	_spawned_nodes.append(treasure_instance)

func clear_spawns():
	if not multiplayer.is_server():
		return

	for node in _spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_nodes.clear()
