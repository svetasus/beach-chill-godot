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

# --- CRITTER LOGIC ---
var _critter_state_timer: float = 0.0
var _critter_is_moving: bool = true
var _critter_move_direction: Vector3 = Vector3.RIGHT

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

@rpc("any_peer", "call_local")
func sync_authority(peer_id: int, should_freeze: bool, impulse: Vector3 = Vector3.ZERO, pos: Vector3 = Vector3.ZERO, rot_y: float = 0.0):
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
	_apply_physics_state.call_deferred(should_freeze, impulse, pos, rot_y)

func _apply_physics_state(should_freeze: bool, impulse: Vector3, pos: Vector3, rot_y: float):

	if should_freeze:
		freeze = true
		_frozen_by_jitter = false # Clear jitter flag if explicitly frozen by player
		top_level = true
		if has_node("CollisionShape3D"):
			get_node("CollisionShape3D").disabled = true
		return # Exit early so we don't accidentally unfreeze below
	
	# 2. Handle the "Release" state (Dropping or Throwing)
	sleeping = false
	freeze = false
	_frozen_by_jitter = false # Clear jitter flag if released
	top_level = false
	if has_node("CollisionShape3D"):
		get_node("CollisionShape3D").disabled = false
	
	# Move to the ghost/hand position
	if pos != Vector3.ZERO:
		global_position = pos
		if impulse == Vector3.ZERO:
			global_rotation = Vector3(0, rot_y, 0)
			sleeping = true # Settle immediately for cozy placement
		else:
			# If it's a throw, let it keep its natural rotation from the air
			global_rotation.y = rot_y

	# Decide: Is this a Placement or a Physics Drop?
	if impulse == Vector3.ZERO:
		# This is a GENTLE placement (E key)
		# We freeze it so it doesn't slide on other items
		freeze = false
		sleeping = true 
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		# This is a THROW or a physics drop
		# We UNFREEZE it so it can fall and react to gravity
		freeze = false
		linear_velocity = impulse
		angular_velocity = Vector3(randf(), randf(), randf()) * 2.0



func _ready():
	# Randomize critter starting state
	_critter_is_moving = randf() > 0.5
	if data is CritterData:
		_critter_state_timer = randf() * (data.move_time if _critter_is_moving else data.pause_time)

	# Ensuring the label starts with the correct text
	if has_node("NamePivot/Name"):
		$NamePivot/Name.text = display_name
	$NamePivot.hide()
	
	# Connecting your original proximity signals
	$NameDetectionArea.body_entered.connect(_on_player_nearby)
	$NameDetectionArea.body_exited.connect(_on_player_left)

	# Enable contact monitoring for jitter detection
	contact_monitor = true
	max_contacts_reported = 5

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

func interact(player: Node3D):
	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("interact"):
			skin.interact(player)

func alt_interact(player: Node3D):
	if not data: return
	if not data.is_furniture and not data is RecipeData: return

	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("alt_interact"):
			skin.alt_interact(player)
		elif skin.has_method("interact"):
			skin.interact(player)

func get_interaction_text() -> String:
	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("get_interaction_text"):
			return skin.get_interaction_text()
	return ""

func get_alt_interaction_text() -> String:
	if $MeshAnchor.get_child_count() > 0:
		var skin = $MeshAnchor.get_child(0)
		if skin.has_method("get_alt_interaction_text"):
			return skin.get_alt_interaction_text()
		elif skin.has_method("get_interaction_text"):
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

# --- Jitter Detection & Freeze logic ---
var _jitter_time: float = 0.0
var _last_velocity: Vector3 = Vector3.ZERO
var _supporting_bodies: Array[Node] = []
var _frozen_by_jitter: bool = false
var _support_original_positions: Dictionary = {}

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if data is CritterData and not freeze and not is_ghost_mode and abs(linear_velocity.y) < 0.1:
		sleeping = false # Force wake up while on the ground so the timer keeps ticking
		_critter_state_timer -= delta
		if _critter_is_moving:
			if _critter_state_timer <= 0:
				_critter_is_moving = false
				_critter_state_timer = data.pause_time
				_critter_move_direction = -_critter_move_direction
			else:
				linear_velocity.x = _critter_move_direction.x * data.move_speed
				linear_velocity.z = _critter_move_direction.z * data.move_speed
		else:
			if _critter_state_timer <= 0:
				_critter_is_moving = true
				_critter_state_timer = data.move_time
			else:
				linear_velocity.x = move_toward(linear_velocity.x, 0, data.move_speed * delta * 5.0)
				linear_velocity.z = move_toward(linear_velocity.z, 0, data.move_speed * delta * 5.0)

	# Wake up logic
	if freeze and _frozen_by_jitter:
		var should_wake_up = false
		for body in _supporting_bodies:
			if not is_instance_valid(body) or body.is_queued_for_deletion():
				should_wake_up = true
				break
			if body is Node3D:
				var original_pos = _support_original_positions.get(body, null)
				if original_pos != null and body.global_position.distance_to(original_pos) > 0.1:
					should_wake_up = true
					break

		if should_wake_up:
			freeze = false
			_frozen_by_jitter = false
			_jitter_time = 0.0
			_supporting_bodies.clear()
			_support_original_positions.clear()
		return

	# Detection logic
	if not freeze and not sleeping:
		var current_vel = linear_velocity.length()
		var current_ang = angular_velocity.length()

		# Small threshold for jitter, large threshold for actual falling
		if current_vel > 0.001 and current_vel < 0.5 and current_ang < 1.0:
			# Check if velocity reverses or stays small
			var dir_dot = linear_velocity.normalized().dot(_last_velocity.normalized())
			if current_vel < 0.1 or dir_dot < 0.5:
				_jitter_time += delta
			else:
				_jitter_time = max(0.0, _jitter_time - delta)
		elif current_vel >= 0.5 or current_ang >= 1.0:
			_jitter_time = 0.0

		_last_velocity = linear_velocity

		if _jitter_time > 1.5:
			# Jitter detected! Freeze the item and record supports
			var colliders = get_colliding_bodies()
			if colliders.size() > 0:
				_supporting_bodies.clear()
				_support_original_positions.clear()
				for body in colliders:
					_supporting_bodies.append(body)
					if body is Node3D:
						_support_original_positions[body] = body.global_position

				freeze = true
				_frozen_by_jitter = true
				_jitter_time = 0.0
				sleeping = true


# --- 6. CLEANUP ---

@rpc("any_peer", "call_local", "reliable")
func destroy_item():
	if not is_queued_for_deletion():
		visible = false
		collision_layer = 0
		collision_mask = 0
		freeze = true

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
