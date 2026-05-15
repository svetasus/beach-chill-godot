extends Area3D


@export var vfx_scene: PackedScene


signal treasure_collected(item_data, collector_id)

func _on_body_entered(body: Node3D) -> void:
	# 1. Server-only referee logic
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("interactables") and "data" in body:
		if body.data.is_collectible:
			# --- CRITICAL: CAPTURE DATA FIRST ---
			# We grab the authority ID BEFORE doing anything else to the body
			var thrower_id = body.get_multiplayer_authority()
			var item_path = body.data.resource_path
			var item_color = body.data.particle_color
			var body_path = body.get_path()
			var spawn_pos = body.global_position
			var money_value = body.data.get_value() if body.data.has_method("get_value") else 10
			
			# Debug to see why it thinks it's the server
			print("Basket detected: ", body.name, " | Authority ID: ", thrower_id, " | Value: ", money_value)
			
			# --- STOP NETWORK ERRORS ---
			# We tell the synchronizer to shut up BEFORE the node dies
			if body.has_node("MultiplayerSynchronizer"):
				var sync_node = body.get_node("MultiplayerSynchronizer")
				sync_node.public_visibility = false
				sync_node.process_mode = PROCESS_MODE_DISABLED
			
			# --- LOCAL CLEANUP ---
			if body is RigidBody3D:
				body.freeze = true
			body.hide()
			
			# --- MONEY LOGIC ---
			if Global.split_money_in_team:
				var players_container = get_node_or_null(Global.PLAYERS_CONTAINER_PATH)
				if players_container:
					var player_count = players_container.get_child_count()
					if player_count > 0:
						var split_money = int(money_value / player_count)
						for player in players_container.get_children():
							if player.has_method("receive_money"):
								player.receive_money.rpc_id(player.name.to_int(), split_money)
								if player.has_method("emit_task_event"):
									player.emit_task_event.rpc_id(player.name.to_int(), "sell", item_path)
			else:
				var players_container = get_node_or_null(Global.PLAYERS_CONTAINER_PATH)
				if players_container:
					var player_node = players_container.get_node_or_null(str(thrower_id))
					if player_node and player_node.has_method("receive_money"):
						player_node.receive_money.rpc_id(thrower_id, money_value)
						if player_node.has_method("emit_task_event"):
							player_node.emit_task_event.rpc_id(thrower_id, "sell", item_path)

			# --- THE SYNC ---
			# We pass all captured data so clients don't have to look it up
			sync_collection.rpc(body_path, item_path, thrower_id, item_color, spawn_pos)
			
			# Final deletion on Server
			body.queue_free()


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
	
@rpc("authority", "call_local", "reliable")
func sync_collection(node_path: NodePath, data_path: String, player_id: int, color: Color, pos: Vector3):
	var item_node = get_node_or_null(node_path)
	
	_spawn_local_vfx(pos, color)
	
	if item_node:
		# 1. Stop all processing and hide it
		item_node.hide()
		item_node.process_mode = PROCESS_MODE_DISABLED
		
		if item_node is RigidBody3D:
			item_node.freeze = true
			item_node.collision_layer = 0
			item_node.collision_mask = 0
		
		# 2. Kill the Synchronizer immediately
		if item_node.has_node("MultiplayerSynchronizer"):
			var sync_node = item_node.get_node("MultiplayerSynchronizer")
			sync_node.public_visibility = false
			sync_node.process_mode = PROCESS_MODE_DISABLED
		
		# 3. THE MANEUVER: Remove it from the world tree
		# This 'orphans' the node so the network loses its address
		if item_node.get_parent():
			item_node.get_parent().remove_child(item_node)
		
		# 4. Final Deletion
		item_node.queue_free()
	
	# Inventory Logic
	var data = load(data_path)
	var player_node = get_tree().root.find_child(str(player_id), true, false)
	if player_node and player_node.has_method("add_to_collection"):
		player_node.add_to_collection(data)
