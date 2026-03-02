extends RigidBody3D
class_name Item

# --- 1. DATA & MULTIPLAYER SYNC ---

@export var data: ItemData : set = _set_data # Using a setter!

@export var data_path: String = "":
	set(val):
		var old_val = data_path
		data_path = val
		# Debug prints preserved from your original version
		print("--- [DEBUG] data_path SET ---")
		print("    From: '", old_val, "'")
		print("    To:   '", val, "'")
		
		if val != "":
			var res = load(val)
			if res:
				_set_data(res)
		else:
			print("    WARNING: data_path set to EMPTY string!")

var item_name: String = "Item"
var display_name: String = "Item"

# --- 2. AUTHORITY & PHYSICS ---

@rpc("any_peer", "call_local")
func sync_authority(peer_id: int, should_freeze: bool, impulse: Vector3 = Vector3.ZERO):
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
	_apply_physics_state.call_deferred(should_freeze, impulse)

func _apply_physics_state(should_freeze: bool, impulse: Vector3):
	freeze = should_freeze
	if not should_freeze:
		sleeping = false
		if impulse != Vector3.ZERO:
			linear_velocity = impulse
			# Added your original random rotation on throw
			angular_velocity = Vector3(randf(), randf(), randf()) * 2.0
	else:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

# --- 3. INITIALIZATION & PROXIMITY ---

func _ready():
	# Ensuring the label starts with the correct text
	if has_node("NamePivot/Name"):
		$NamePivot/Name.text = item_name
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
		if data.scene:
			var skin = data.scene.instantiate()
			$MeshAnchor.add_child(skin)
			
			if not skin.is_node_ready():
				await skin.ready
			
			_update_collision_from_skin(skin)
			

		else:
			print("--- [ITEM] ERROR: No scene found in data! ---")

# --- 5. COLLISION RECURSION ---

func _update_collision_from_skin(skin_node):
	var custom_node = _find_shape_recursive(skin_node)
	
	if custom_node:
		# Copy the shape and transform from the skin to our root collision
		$CollisionShape3D.shape = custom_node.shape
		$CollisionShape3D.global_transform = custom_node.global_transform
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

# --- 6. CLEANUP ---

func _exit_tree():
	# Prevent signal errors when items are combined/deleted
	for sig in get_signal_list():
		var connections = get_signal_connection_list(sig.name)
		for conn in connections:
			conn.signal.disconnect(conn.callable)
