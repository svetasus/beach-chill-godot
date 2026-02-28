extends RigidBody3D
class_name Item

# This allows you to change the name in the Inspector 
# for different ingredients (Tomato, Potato, etc.)


@export var data: ItemData : set = _set_data # Using a setter!
#@onready var mesh_instance = $MeshInstance3D # Assuming you added one
@export var data_path: String = "":
	set(val):
		var old_val = data_path
		data_path = val
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

@rpc("any_peer", "call_local")
func sync_authority(peer_id: int, should_freeze: bool, impulse: Vector3 = Vector3.ZERO):
	# SAFETY: If the basket is already deleting this, stop syncing
	if not is_inside_tree() or is_queued_for_deletion():
		return


	# 1. SET AUTHORITY FIRST
	# Both the node and the synchronizer must be updated
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
	
	# 2. WAIT A TINY BIT (Deferred)
	# This ensures the 'freeze' and 'velocity' changes happen 
	# AFTER the authority has been settled in the engine.
	_apply_physics_state.call_deferred(should_freeze, impulse)

func _apply_physics_state(should_freeze: bool, impulse: Vector3):
	freeze = should_freeze
	if not should_freeze:
		sleeping = false
		if impulse != Vector3.ZERO:
			linear_velocity = impulse
			angular_velocity = Vector3(randf(), randf(), randf()) * 2.0
	else:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


func _ready():
	$NamePivot/Name.text = item_name
	$NamePivot.hide()
	
	$NameDetectionArea.body_entered.connect(_on_player_nearby)
	$NameDetectionArea.body_exited.connect(_on_player_left)


func show_name(should_show: bool):
	$NamePivot.visible = should_show
	
	
func _on_player_nearby(body):
	# Check if the thing that entered is a player
	if body.is_in_group("players") or body is CharacterBody3D:
		# If it's the LOCAL player, show the label
		if body.is_multiplayer_authority():
			$NamePivot.show()

func _on_player_left(body):
	if body.is_in_group("players") or body is CharacterBody3D:
		if body.is_multiplayer_authority():
			$NamePivot.hide()
			
			
func _physics_process(_delta):
	
	if Input.is_action_just_pressed("ui_focus_next"): # Press 'Tab' to check
		print("Item: ", name, " | Authority: ", get_multiplayer_authority(), " | I am Server: ", multiplayer.is_server())
	

func _set_data(new_data):
	#print("--- [DEBUG] _set_data CALLED ---")
	if new_data == null: 
		return
	if data == new_data and item_name != "Item": # "Item" being your placeholder name
		return
	
	#print("    Incoming Resource Name: ", new_data.name)
	
	if data == new_data and $MeshAnchor.get_child_count() > 0:
		print("    SKIPPED: Data is identical to current state")
		return
		
	#print("--- 1. SET DATA CALLED ---")
	data = new_data
	if not is_inside_tree(): 
		print("--- WAITING FOR TREE ---")
		await ready
	
	if data:
		#print("--- 2. DATA LOADED: ", data.name, " ---")
		item_name = data.name
		
		var old_name = item_name
		data = new_data
		item_name = data.name
		display_name = data.display_name
		
		#print("    NAME CHANGE: '", old_name, "' -> '", item_name, "'")
		
		if has_node("NamePivot/Name"):
			var label = $NamePivot/Name
			label.text = display_name
			#print("    UI UPDATED: Label now says '", label.text, "'")
		else:
			print("    ERROR: Could not find Label node at NamePivot/Name!")
		
		# 1. Cleanup old visuals
		for child in $MeshAnchor.get_children():
			child.queue_free()
			
		# 2. Spawn Visuals
		if data.scene:
			#print("--- 3. INSTANTIATING SCENE ---")
			var skin = data.scene.instantiate()
			$MeshAnchor.add_child(skin)
			
			# We wait for the node to fully enter the tree
			if not skin.is_node_ready():
				#print("--- WAITING FOR SKIN SIGNAL ---")
				await skin.ready
			
			#print("--- 4. SKIN READY, UPDATING COLLISION ---")
			_update_collision_from_skin(skin)
		else:
			print("--- 3. ERROR: NO SCENE FOUND IN DATA ---")
	else:
		print("--- 2. ERROR: NO DATA RECEIVED ---")

func _update_collision_from_skin(skin_node):
	#print("--- 5. LOOKING FOR SHAPE IN: ", skin_node.name, " ---")
	var custom_node = _find_shape_recursive(skin_node)
	
	if custom_node:
		#print("--- 6. FOUND SHAPE: ", custom_node.name, " ---")
		# Force the copy
		$CollisionShape3D.shape = custom_node.shape
		$CollisionShape3D.global_transform = custom_node.global_transform
		$CollisionShape3D.disabled = false
		#print("--- 7. COLLISION UPDATED SUCCESSFULLY ---")
	else:
		print("--- 6. ERROR: NO COLLISIONSHAPE3D FOUND IN SKIN ---")

func _find_shape_recursive(node):
	if node is CollisionShape3D:
		return node
	for child in node.get_children():
		var found = _find_shape_recursive(child)
		if found: return found
	return null

# Helper function to see if the visual scene brought its own physics
func _check_for_collision(node):
	if node is CollisionShape3D: return true
	for child in node.get_children():
		if _check_for_collision(child): return true
	return false
	
	
	
func _process(_delta):
	# If we are being deleted, stop trying to sync or do math
	if is_queued_for_deletion():
		return

func _exit_tree():
	if has_node("MultiplayerSynchronizer"):
		var sync = get_node("MultiplayerSynchronizer")
		sync.public_visibility = false
	# This runs the moment queue_free() is called
	# We disconnect everything to prevent "Lambda capture" errors
	for sig in get_signal_list():
		var connections = get_signal_connection_list(sig.name)
		for conn in connections:
			conn.signal.disconnect(conn.callable)
