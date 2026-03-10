extends CharacterBody3D

@export var driver_id: int = 0
var driver_node: Node3D = null

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
		# to match the cart's current rotation so the cart doesn't violently
		# spin around and fling items out of the basket.
		if multiplayer.get_unique_id() == new_id and driver_node != null:
			driver_node.global_rotation.y = global_rotation.y

	else:
		driver_node = null
		set_collision_mask_value(2, true)

func _physics_process(delta):
	if driver_node and is_instance_valid(driver_node):
		# Only the multiplayer authority should process the exact position updates
		if is_multiplayer_authority():
			# Keep the cart in front of the player
			# Assuming the player's 'forward' is -Z. We want the cart 'handle' to be close to the player,
			# but since Handle is at +Z (+1.0ish), the cart itself should be slightly ahead of the player.
			var player_forward = -driver_node.global_transform.basis.z.normalized()
			var target_pos = driver_node.global_position + (player_forward * 1.5)

			# Maintain ground level, keeping Y from player
			target_pos.y = driver_node.global_position.y

			global_position = global_position.lerp(target_pos, 15.0 * delta)

			# Rotation matches player Y rotation, so the back (handle) faces the player
			var current_rot = global_rotation
			var target_rot = driver_node.global_rotation
			current_rot.y = lerp_angle(current_rot.y, target_rot.y, 15.0 * delta)
			global_rotation = Vector3(current_rot.x, current_rot.y, current_rot.z)

func remove_item(item_node: Node3D):
	if inventory_nodes.has(item_node):
		inventory_nodes.erase(item_node)
		if item_node.has_method("unlock_from_cart"):
			item_node.unlock_from_cart()
