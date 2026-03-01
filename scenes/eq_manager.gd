extends Node3D

var carried_item = null
@onready var player = get_owner() # Access the root Player node

func _process(_delta):
	if not is_multiplayer_authority(): return
	
	if carried_item:
		carried_item.global_transform = global_transform
		# Force-mute the synchronizer while held
		if carried_item.has_node("MultiplayerSynchronizer"):
			var sync_node = carried_item.get_node("MultiplayerSynchronizer")
			sync_node.set_process(false)
			sync_node.set_physics_process(false)

func pick_up(item):
	if carried_item != null: return
	
	# Multiplayer Authority Check
	if item.freeze == true and item.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	
	var my_id = multiplayer.get_unique_id()
	
	if item.has_method("sync_authority"):
		item.sync_authority.rpc(my_id, true)
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if item.get_multiplayer_authority() == my_id:
		carried_item = item
		if item.has_node("CollisionShape3D"):
			item.get_node("CollisionShape3D").disabled = true
		
		item.global_transform = global_transform
		item.freeze = true
		
		# Tool-specific check
		if item.has_method("set_active_treasure") and player.current_treasure != null:
			item.set_active_treasure(player.current_treasure)

func drop_item():
	if carried_item == null: return
	
	var item = carried_item
	carried_item = null
	
	if item.has_node("CollisionShape3D"):
		item.get_node("CollisionShape3D").disabled = false
	
	item.sync_authority.rpc(multiplayer.get_unique_id(), false, Vector3.ZERO)

func throw_item(force: float):
	if carried_item == null: return
	
	var item = carried_item
	carried_item = null
	
	var launch_dir = (-global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
	var final_velocity = launch_dir * force
	
	item.global_position = global_position + (launch_dir * 0.5)
	
	if item.has_node("CollisionShape3D"):
		item.get_node("CollisionShape3D").disabled = false
	
	await get_tree().physics_frame
	item.sync_authority.rpc(multiplayer.get_unique_id(), false, final_velocity)
	
	# Hand back to server after a delay
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(item):
			item.sync_authority.rpc(1, false)
	)
