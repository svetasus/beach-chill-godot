extends RigidBody3D
class_name Item

# --- 1. DATA & MULTIPLAYER SYNC ---

@export var data: ItemData : set = _set_data # Using a setter!
@export var ghost_material: Material
@export var is_autospawned: bool = false

@export var data_path: String = "":
	set(val):
		var old_val = data_path
		data_path = val
		# Debug prints preserved from your original version
		#print("--- [DEBUG] data_path SET ---")
		#print("    From: '", old_val, "'")
		print("    To:   '", val, "'")
		
		if val != "":
			var res = load(val)
			if res:
				_set_data(res)
		else:
			print("    WARNING: data_path set to EMPTY string!")

var item_name: String = "Item"
var display_name: String = "Item"

var is_ghost_mode: bool = false

var locked_to_cart: Node3D = null
var cart_offset: Vector3 = Vector3.ZERO
var rotation_offset: Basis

# --- 2. AUTHORITY & PHYSICS ---
var is_ghost_valid: bool = true

func set_ghost_appearance(active: bool):
	is_ghost_mode = active
	_apply_material_to_anchor($MeshAnchor, active, is_ghost_valid)

func set_ghost_valid(valid: bool):
	if is_ghost_valid != valid:
		is_ghost_valid = valid
		if is_ghost_mode:
			_apply_material_to_anchor($MeshAnchor, true, is_ghost_valid)

func _apply_material_to_anchor(node: Node, active: bool, valid: bool = true):
	if node is MeshInstance3D:
		# If active is true, we force the ghost material. 
		# If false, we set it to null, which returns it to the original material.
		if active:
			if valid:
				node.material_override = ghost_material
			else:
				var invalid_mat = ghost_material.duplicate()
				invalid_mat.albedo_color = Color(1, 0, 0, 0.5)
				node.material_override = invalid_mat
		else:
			node.material_override = null
		
	for child in node.get_children():
		_apply_material_to_anchor(child, active, valid)

var is_flying: bool = false
var is_held: bool = false
var throw_tween: Tween

enum State {
	RESTING = 0,
	HELD = 1,
	THROWN = 2
}

@rpc("any_peer", "call_local")
func sync_authority(peer_id: int, state: int, target_pos: Vector3 = Vector3.ZERO, pos: Vector3 = Vector3.ZERO, rot_y: float = 0.0, throw_duration: float = 0.5):
	if not is_node_ready():
		await ready
	# SAFETY: If the basket is already deleting this, stop syncing
	if not is_inside_tree() or is_queued_for_deletion():
		return

	# 1. SET AUTHORITY FIRST
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
	
	# 2. WAIT A TINY BIT (Deferred)
	_apply_state.call_deferred(state, target_pos, pos, rot_y, throw_duration)


func _apply_state(state: int, target_pos: Vector3, pos: Vector3, rot_y: float, throw_duration: float):

	# Update the state internally
	is_held = (state == State.HELD)

	if is_held:
		top_level = true
		if has_node("CollisionShape3D"):
			get_node("CollisionShape3D").disabled = true
		is_flying = false
		if throw_tween and throw_tween.is_running():
			throw_tween.kill()
		return
	
	# Handle the "Release" state (Dropping or Throwing)
	top_level = false
	if has_node("CollisionShape3D"):
		get_node("CollisionShape3D").disabled = false
	
	# Move to the start position if placing or starting throw
	if pos != Vector3.ZERO:
		global_position = pos
		global_rotation.y = rot_y

	if throw_tween and throw_tween.is_running():
		throw_tween.kill()
		is_flying = false

	if state == State.THROWN and target_pos != Vector3.ZERO:
		is_flying = true
		throw_tween = create_tween()
		throw_tween.set_parallel(true)

		# Tween X and Z directly to target
		var target_xz = Vector3(target_pos.x, global_position.y, target_pos.z)
		var current_xz = Vector3(global_position.x, global_position.y, global_position.z)
		throw_tween.tween_property(self, "global_position:x", target_pos.x, throw_duration).set_ease(Tween.EASE_IN_OUT)
		throw_tween.tween_property(self, "global_position:z", target_pos.z, throw_duration).set_ease(Tween.EASE_IN_OUT)

		var arc_height = current_xz.distance_to(target_xz) * 0.4
		if arc_height < 1.0: arc_height = 1.0

		var mid_y = max(global_position.y, target_pos.y) + arc_height

		# Animate Y (Up, then Down)
		throw_tween.tween_property(self, "global_position:y", mid_y, throw_duration / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		throw_tween.tween_property(self, "global_position:y", target_pos.y, throw_duration / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(throw_duration / 2.0)

		# Spin around Y while flying
		throw_tween.tween_property(self, "global_rotation:y", global_rotation.y + PI * 2, throw_duration)

		throw_tween.chain().tween_callback(func(): is_flying = false)


func _ready():
	# Ensuring the label starts with the correct text
	if has_node("NamePivot/Name"):
		$NamePivot/Name.text = display_name
	$NamePivot.hide()
	
	# Connecting your original proximity signals
	$NameDetectionArea.body_entered.connect(_on_player_nearby)
	$NameDetectionArea.body_exited.connect(_on_player_left)

func show_name(should_show: bool):
	$NamePivot.visible = should_show

func _on_player_nearby(body):
	if body.is_in_group("players") or body is CharacterBody3D:
		if body.is_multiplayer_authority():
			$NamePivot.show()

func _on_player_left(body):
	if body.is_in_group("players") or body is CharacterBody3D:
		if body.is_multiplayer_authority():
			$NamePivot.hide()

# --- 4. THE CORE DATA LOGIC (FIXED FOR MULTIPLAYER) ---

func _set_data(new_data):
	if new_data == null: 
		return
		
	# FIX: Clients often receive 'data' via sync but don't have the visuals yet.
	# This check ensures we build the mesh even if 'data' looks identical.
	var needs_visuals = $MeshAnchor.get_child_count() == 0
	
	if data == new_data and not needs_visuals:
		return
		
	data = new_data
	
	# Ensure the node is actually in the tree so we can find child nodes
	if not is_inside_tree(): 
		await ready
	
	if data:
		item_name = data.name
		display_name = data.display_name
		
		# Update UI Label
		if has_node("NamePivot/Name"):
			$NamePivot/Name.text = display_name
		
		# 1. Cleanup old visuals
		for child in $MeshAnchor.get_children():
			child.queue_free()
			
		# 2. Spawn Visuals (The Scene from your ItemData)
		# Ensure data_path is populated if this item was manually placed with only 'data'
		if data_path == "" and data.resource_path != "":
			data_path = data.resource_path

		if data.scene:
			var skin = data.scene.instantiate()
			$MeshAnchor.add_child(skin)
			
			if not skin.is_node_ready():
				await skin.ready
			
			_update_collision_from_skin(skin)
			

		else:
			print("--- [ITEM] ERROR: No scene found in data! ---")

func alt_interact(player: Node3D):
	if not data or not data.is_furniture: return

	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("interact"):
			skin.interact(player)

func get_alt_interaction_text() -> String:
	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("get_interaction_text"):
			return skin.get_interaction_text()

	if data and data.is_furniture:
		return "[R] Interact"
	return ""

func apply_item(item: Node3D) -> bool:
	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("apply_item"):
			return skin.apply_item(item)
	return false

# --- 5. COLLISION RECURSION ---

func _update_collision_from_skin(skin_node):
	var custom_node = _find_shape_recursive(skin_node)
	
	if custom_node:
		# Copy the shape from the skin
		$CollisionShape3D.shape = custom_node.shape

		# Calculate the exact local transform relative to this RigidBody3D
		# This prevents global_transform sync issues that cause items to stand vertically
		var local_trans = Transform3D()
		var current = custom_node
		while current and current != self:
			local_trans = current.transform * local_trans
			current = current.get_parent()

		$CollisionShape3D.transform = local_trans
		$CollisionShape3D.disabled = false
	else:
		print("--- [ITEM] ERROR: No CollisionShape3D found in skin! ---")

func _find_shape_recursive(node):
	if node is CollisionShape3D:
		return node
	for child in node.get_children():
		var found = _find_shape_recursive(child)
		if found: return found
	return null
	
	
# Called by the Server when dropped in a cart
func lock_to_cart(cart: Node3D):
	if not multiplayer.is_server(): return
	
	locked_to_cart = cart
	
# Called by the Server when removed from the cart
func unlock_from_cart():
	if not multiplayer.is_server(): return
	
	locked_to_cart = null
		
@rpc("any_peer", "call_local")
func request_unlock_from_cart():
	if multiplayer.is_server():
		if locked_to_cart and locked_to_cart.has_method("remove_item"):
			locked_to_cart.remove_item(self)
		else:
			unlock_from_cart()

# --- 6. CLEANUP ---

@rpc("any_peer", "call_local", "reliable")
func destroy_item():
	if not is_queued_for_deletion():
		visible = false
		collision_layer = 0
		collision_mask = 0

		# Give the RPC time to reach clients before actually deleting
		if multiplayer.is_server():
			get_tree().create_timer(0.1).timeout.connect(queue_free)
		else:
			queue_free()

func _exit_tree():
	# Prevent signal errors when items are combined/deleted
	for sig in get_signal_list():
		var connections = get_signal_connection_list(sig.name)
		for conn in connections:
			conn.signal.disconnect(conn.callable)
