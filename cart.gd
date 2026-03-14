extends CharacterBody3D

@export var driver_id: int = 0
var driver_node: Node3D = null

@export var floor_offset: float = 0.45

var inventory_nodes: Array[Node3D] = []

func _ready():
	# Allow Area3Ds to redirect the "grab" or "deposit" interactions to the Cart script
	$HandleZone.set_meta("is_cart_handle", true)
	$HandleZone.set_meta("cart_node", self)

	$BasketZone.set_meta("is_cart_basket", true)
	$BasketZone.set_meta("cart_node", self)

func deposit_item_cart(item_node: Node3D):
	if not multiplayer.is_server(): return
	
	if not inventory_nodes.has(item_node):
		inventory_nodes.append(item_node)
		
		if item_node is RigidBody3D:
			item_node.linear_damp = 15.0
			item_node.angular_damp = 15.0

		if item_node.has_method("lock_to_cart"):
			item_node.lock_to_cart(self)
			
		print("SERVER: Physical item locked into cart. Total: ", inventory_nodes.size())

func grab_cart(player: Node3D, peer_id: int):
	if not multiplayer.is_server(): return

	if driver_id != 0 and driver_id != peer_id:
		print("SERVER: Cart is already driven by someone else!")
		return

	driver_id = peer_id
	driver_node = player

	# Give the player authority over the cart so they can move it smoothly
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

	# Disable cart collision with player so it doesn't push the player around while attached
	set_collision_mask_value(2, false)

	# Notify clients
	_rpc_sync_driver.rpc(peer_id, player.get_path())

func release_cart():
	if not multiplayer.is_server(): return

	driver_id = 0
	driver_node = null

	# Return authority to server
	set_multiplayer_authority(1)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)

	# Re-enable collision with player
	set_collision_mask_value(2, true)

	_rpc_sync_driver.rpc(0, NodePath())

@rpc("call_local", "any_peer", "reliable")
func _rpc_sync_driver(new_id: int, player_path: NodePath):
	driver_id = new_id
	if new_id != 0 and not player_path.is_empty():
		driver_node = get_node_or_null(player_path)
		set_collision_mask_value(2, false)

		# If we are the player who just grabbed the cart, snap our own rotation
		# and position to match the cart's current state so the cart doesn't violently
		# yank itself towards us on the first frame and fling items out of the basket.
		if multiplayer.get_unique_id() == new_id and driver_node != null:
			driver_node.global_rotation.y = global_rotation.y

			# Snap the player perfectly behind the cart based on its forward axis
			var cart_forward = -global_transform.basis.z.normalized()
			var ideal_player_pos = global_position - (cart_forward * 1.5)

			# Update X and Z, keep Y so the player doesn't float or sink
			driver_node.global_position.x = ideal_player_pos.x
			driver_node.global_position.z = ideal_player_pos.z

	else:
		driver_node = null
		set_collision_mask_value(2, true)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	var is_driven = driver_node and is_instance_valid(driver_node)

	if is_driven:
		# --- DRIVEN LOGIC ---
		# Reset velocity so we don't build up weird physics forces
		velocity = Vector3.ZERO

		# 1. Calculate ideal X/Z position in front of player
		var player_forward = -driver_node.global_transform.basis.z.normalized()
		var target_pos = driver_node.global_position + (player_forward * 1.5)

		# 2. Find the floor height for the cart using a downward raycast
		var space_state = get_world_3d().direct_space_state
		# Raycast from high above the target position down to below the floor
		var ray_origin = Vector3(target_pos.x, driver_node.global_position.y + 2.0, target_pos.z)
		var ray_end = ray_origin + Vector3(0, -10.0, 0)

		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		# Ignore the cart itself and the player
		query.exclude = [self.get_rid(), driver_node.get_rid()]
		# Only hit environment/static bodies, not other items (layers 1 default)
		query.collision_mask = 1

		var result = space_state.intersect_ray(query)

		var floor_normal = Vector3.UP
		if result:
			# If we found the floor, snap the target Y to the hit point + floor_offset
			# so the cart doesn't sink into the ground.
			target_pos.y = result.position.y + floor_offset
			floor_normal = result.normal
		else:
			# Fallback if no floor found (e.g., hanging off an edge)
			target_pos.y = driver_node.global_position.y + floor_offset

		# 3. Smoothly lerp position towards the target
		global_position = global_position.lerp(target_pos, 15.0 * delta)

		# 4. Handle Rotation & Floor Alignment safely
		# We want the cart's forward to match the player's forward on the XZ plane
		var target_forward = player_forward
		# Prevent parallel vectors for cross product
		if abs(floor_normal.dot(target_forward)) < 0.99:
			# X = Forward x Up
			var right = target_forward.cross(floor_normal).normalized()
			# Z = Up x Right
			var forward = floor_normal.cross(right).normalized()

			var target_basis = Basis(right, floor_normal, -forward)
			global_transform.basis = global_transform.basis.slerp(target_basis, 15.0 * delta)

	else:
		# --- ABANDONED LOGIC ---
		var wants_to_freeze = false

		# Always apply gravity when not driven
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			# Apply friction/drag on XZ when not driven
			velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 10.0 * delta)

			# If we are barely moving on the floor, freeze completely to stop item jitter
			if velocity.length_squared() < 0.01:
				velocity = Vector3.ZERO
				wants_to_freeze = true

		if not wants_to_freeze:
			move_and_slide()

			# Rotate to align with the floor if resting on it
			if is_on_floor():
				var floor_normal = get_floor_normal()
				var target_forward = -global_transform.basis.z.normalized()

				if abs(floor_normal.dot(target_forward)) < 0.99:
					var right = target_forward.cross(floor_normal).normalized()
					var forward = floor_normal.cross(right).normalized()
					var target_basis = Basis(right, floor_normal, -forward)
					global_transform.basis = global_transform.basis.slerp(target_basis, 10.0 * delta)

func remove_item(item_node: Node3D):
	if inventory_nodes.has(item_node):
		inventory_nodes.erase(item_node)

		if item_node is RigidBody3D:
			item_node.linear_damp = 2.0
			item_node.angular_damp = 2.0

		if item_node.has_method("unlock_from_cart"):
			item_node.unlock_from_cart()
