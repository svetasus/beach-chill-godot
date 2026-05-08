extends Area3D

# This will be the crate or item that appears when dug up
#@export var item_to_spawn: PackedScene 
# Drag your Tomato, Metal Detector, or other Item scenes here in the Inspector
@export var loot_table: Array[ItemData]
@export var base_item_scene: PackedScene 
@export var sand_particles: PackedScene

@onready var marker = $LocationMarker

func _ready():
	pass

func _on_body_entered(body):
	#print("Something entered the circle: ", body.name) 
	if body.is_in_group("players") and body.is_multiplayer_authority():
		# Tell the player's detector to start beeping
		body.set_near_treasure(self, true)

func _on_body_exited(body):
	if body.is_in_group("players") and body.is_multiplayer_authority():
		# Tell the player's detector to stop
		body.set_near_treasure(self, false)


func dig_up():
	if marker:
		marker.hide()
	
	# 1. SHUT IT DOWN LOCALLY (The Fix)
	# Disable the area so the player can't trigger 'dig_up' again 
	# while waiting for the network.
	monitorable = false
	monitoring = false

	# 1. LOCAL VISUAL: Play for the person who clicked INSTANTLY
	_play_particles_locally(global_position)
	
	# Only the Server (Host) should handle spawning to keep things synced
	# 2. THE FIX: Always route the "Deletion/Spawning" through the Server
	if multiplayer.is_server():
		_perform_spawn() # Server just does it
	else:
		# Client asks server to do it. 
		# Server will then call _perform_spawn which deletes it for EVERYONE.
		spawn_loot_request.rpc_id(1)


@rpc("any_peer", "call_local")
func spawn_loot_request():
	# Extra safety: check if the server already handled this
	if is_inside_tree():
		_perform_spawn()


func _perform_spawn():
	if not multiplayer.is_server(): return
	
	# 1. Visuals and Cleanup
	spawn_particles_visual.rpc(global_position)
	
	if loot_table.size() == 0: 
		_sync_deletion.rpc()
		return
	
	
	var total_weight = 0.0
	for item_data in loot_table:
		total_weight += item_data.get_chance()

	# Generate a random number between 0 and the total weight
	var random_weight = randf() * total_weight
	
	print("random weight: ", random_weight)
	var current_weight = 0.0
	
	for item_data in loot_table:
		current_weight += item_data.get_chance()
		if random_weight <= current_weight:
			var selected_resource = item_data
			var loot_data_path = selected_resource.resource_path # Get the string path automatically
			
			# 3. Spawn the Container (BaseItem)
			var loot_instance = base_item_scene.instantiate()
			
			# IMPORTANT: Add to the world BEFORE setting data
			# This ensures the MultiplayerSpawner sees it
			var items_container = get_tree().root.get_node_or_null(Global.ITEMS_CONTAINER_PATH)
			if items_container:
				items_container.add_child(loot_instance, true)
			else:
				get_parent().add_child(loot_instance, true)
			
			# 4. Initialize the Item
			loot_instance.global_position = global_position + Vector3(0, 0.5, 0)
			
			# This triggers the _set_data() logic we wrote earlier!
			loot_instance.data_path = loot_data_path 
			
			print(loot_instance.display_name)
			# 5. The "Pop" Physics using Tween
			# BaseItem is an Area3D, so we animate the pop
			if loot_instance.has_method("sync_authority"):
				var final_target = global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))

				# Raycast down to find floor for final target
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(final_target + Vector3(0, 1.0, 0), final_target + Vector3(0, -5.0, 0))
				var result = space_state.intersect_ray(query)
				if result:
					final_target = result.position

				# We temporarily set it as THROWN (2) with the server authority
				loot_instance.sync_authority(1, 2, final_target, global_position + Vector3(0, 0.5, 0), 0.0, 0.6)

				# Then revert to RESTING (0)
				get_tree().create_timer(0.6).timeout.connect(func():
					if is_instance_valid(loot_instance):
						loot_instance.sync_authority(1, 0, Vector3.ZERO, final_target, 0.0, 0.0)
				)

			break						


	
	
	# 6. Delete the point
	_sync_deletion.rpc()
	
		
		
func _play_particles_locally(pos):
	if sand_particles:
		var poof = sand_particles.instantiate()
		get_tree().root.add_child(poof)
		poof.global_position = pos + Vector3(0, 0.5, 0)
		if poof is CPUParticles3D:
			poof.restart()
			poof.emitting = true

# This is the network version that only runs on "Other People's" screens
@rpc("any_peer", "call_remote") # Changed from call_local to call_remote
func spawn_particles_visual(pos):
	_play_particles_locally(pos)


@rpc("any_peer", "call_local", "reliable")
func _sync_deletion():
	queue_free()


func reveal_location(dist):
	marker.show()
	
	# DEBUG: Delete this once it works
	# print("Pulsing! Distance: ", dist) 
	
	marker.show()
	
	
	# sin() creates a wave that goes from -1 to 1
	var pulse_speed = Time.get_ticks_msec() * 0.007
	var pulse_amount = (sin(pulse_speed) * 0.1) + 1.0 # Result is 0.9 to 1.1
	
	
	# Distance-based scale * Pulse wave
	var base_scale = remap(clamp(dist, 0.5, 3.0), 0.5, 3.0, 0.5, 1.5)
	var final_s = base_scale * pulse_amount
	marker.scale = Vector3(final_s, final_s, final_s)
	
	# 4. TRANSPARENCY
	var alpha = remap(clamp(dist, 0.5, 3.0), 0.5, 3.0, 1.0, 0.0)
	marker.transparency = 1.0 - alpha

func hide_location():
	if marker.visible:
		marker.hide()
