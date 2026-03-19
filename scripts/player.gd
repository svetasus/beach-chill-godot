extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const THROW_FORCE = 16.0
const DIG_DIST = 1.5

@onready var shapecast = $Body/Head/Camera3D/InteractionShape
@onready var hand = $Body/Head/Camera3D/HandMarker
@onready var action_label = $PlayerUI/ActionLabel
@onready var placement_ray = $Body/Head/Camera3D/PlacementRay
@onready var state_sit = $State_Sit
@onready var state_stand = $State_Stand

@onready var tp_camera = $Body/SpringArm3D/ThirdPersonCamera
@onready var tp_spring_arm = $Body/SpringArm3D
@onready var tp_shapecast = $Body/ThirdPersonInteractionShape
@onready var tp_placement_ray = $Body/ThirdPersonPlacementRay

@export var is_third_person: bool = false
@export var mouse_sensitivity = 0.002

# This variable will be synced across the network
@export var eye_color: Color = Color.BLUE

# Sync this variable in MultiplayerSynchronizer so late joiners know the state!
@export var is_sitting: bool = false

var rotation_offset: float = 0.0
@export var rotation_speed: float = 0.5 # How fast it rotates with scroll

var current_ui: Control = null

var is_typing = false
var carried_item = null
var catch_cooldown = false
var last_hovered_item = null

var nearby_treasures: Array[Node3D] = [] # Change current_treasure to an Array
var current_treasure = null # This will now be the NEAREST one
var can_dig = false
var jump_queued = false
var can_place = true
var current_furniture = null
var _highlighted_node = null


# Stores item names and their counts: {"Pink Shell": 3, "Old Coin": 1}
var collection = {}

var money: int = 0

# Signal to tell the UI to refresh
signal collection_updated(new_collection)

func get_save_path() -> String:
	if is_multiplayer_authority():
		return "user://player_money_" + Global.account_id + ".save"
	else:
		return "user://player_money_" + str(name) + ".save"

func save_money():
	var file = FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(str(money))
		file.close()

func load_money():
	var path = get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			money = content.to_int()
			file.close()

func _enter_tree() -> void:
	pass

func _ready():
	_ready_highlight_system()
	placement_ray.set_collision_mask_value(4, true) # Layer 8 for tent collision bounds
	tp_placement_ray.set_collision_mask_value(4, true)

	tp_spring_arm.top_level = true
	
	# WAIT for the spawner to actually name the node (e.g., "1" or "2384923")
	# If the name is "Player" or "@Player", authority will fail.
	
	
	await get_tree().process_frame
	
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)
	
	$Nickname.text = name
	
	_update_sit_visuals(is_sitting)
	
	# RE-EVALUATE authority after the name change
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())
		
	if is_multiplayer_authority():
		_apply_camera_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$PlayerUI.show()
		
		set_physics_process(true)
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		#print("SUCCESS: I am the BOSS of ", name)
		
		eye_color = Color(randf(), randf(), randf()) # Random RGB
		apply_eye_color(eye_color)
		
		load_money()
		update_money_ui()
		
	else:
		# THIS IS SOMEONE ELSE: Turn off their camera on my screen
		$Body/Head/Camera3D.current = false
		tp_camera.current = false
		$PlayerUI.hide()
		set_physics_process(false) 
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		print("GHOST: I am observing ", name)
		
		#BUT: I still want to be able to catch things on my own screen
		# So we keep the CatchZone monitoring active!
		$Body/Head/Camera3D/CatchZone.monitoring = true
		
		
		# Wait a tiny bit for the network to send the color, then apply it
		await get_tree().create_timer(0.1).timeout
		apply_eye_color(eye_color)
		_update_sit_visuals(is_sitting)
		
	# Connect the 'Catch' signal
	$Body/Head/Camera3D/CatchZone.body_entered.connect(_on_catch_zone_body_entered)


func _apply_camera_mode():
	# Update camera
	if is_third_person:
		tp_camera.make_current()
	else:
		$Body/Head/Camera3D.make_current()

	# Update Crosshair (if it exists)
	var main_ui = get_node_or_null("/root/Main/UI")
	if main_ui:
		var crosshair = main_ui.get_node_or_null("Crosshair")
		if crosshair:
			crosshair.visible = not is_third_person

func _physics_process(delta: float) -> void:
	
	if not is_multiplayer_authority() or is_typing: return
	
	# Snap the SpringArm to the player (plus an offset) so it follows them but doesn't inherit rotation
	if tp_spring_arm.top_level:
		tp_spring_arm.global_position = global_position + Vector3(0, 1.0, 0)

	if current_furniture != null and is_instance_valid(current_furniture):
		# Snap to the furniture's position
		global_position = current_furniture.global_position + Vector3(0, 0.5, 0)
		# Face the same way as the furniture (or opposite, depending on model)
		# global_rotation.y = current_furniture.global_rotation.y
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if jump_queued:
		jump_queued = false
		if is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var direction := Vector3.ZERO
	if is_third_person:
		# Direction is based on the SpringArm's orientation
		var cam_basis = tp_spring_arm.global_transform.basis
		direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		# Flatten the direction
		direction.y = 0
		direction = direction.normalized()

		# Rotate the player body to face the movement direction
		if direction != Vector3.ZERO:
			var target_rot = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 10.0 * delta)
	else:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()

	# Stair-stepping logic (like the cart's floor checking)
	if direction != Vector3.ZERO and is_on_floor():
		var space_state = get_world_3d().direct_space_state
		# Raycast from 0.4 units high (knee height), looking down 0.5 units,
		# positioned slightly ahead of the player in their movement direction
		var forward_offset = direction * 0.5
		var ray_origin = global_position + forward_offset + Vector3(0, 0.4, 0)
		var ray_end = ray_origin + Vector3(0, -0.5, 0)

		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [self.get_rid()]
		query.collision_mask = 1 # Only hit environment

		var result = space_state.intersect_ray(query)
		if result:
			var step_height = result.position.y - global_position.y
			# If the ground ahead is slightly higher than our current feet (between 0.05 and 0.4 units high)
			if step_height > 0.05 and step_height <= 0.4:
				# Smoothly slide the player up the step
				global_position.y = lerp(global_position.y, result.position.y, 15.0 * delta)
	
	
func _unhandled_input(event):
	
	# IF THIS IS NOT MY CHARACTER, DO NOT MOVE THE CAMERA/LASER
	if not is_multiplayer_authority() or is_typing: return
	
	# This checks if the mouse is moving
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return

	# This checks if the mouse is moving
	if event is InputEventMouseMotion:
		if is_third_person:
			# Rotate the spring arm around the player
			tp_spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
			tp_spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
			# Clamp vertical rotation
			tp_spring_arm.rotation.x = clamp(tp_spring_arm.rotation.x, deg_to_rad(-80), deg_to_rad(45))
		else:
			# 1. Rotate the whole player left and right (Y axis)
			rotate_y(-event.relative.x * mouse_sensitivity)

			# 2. Rotate the camera up and down (X axis)
			$Body/Head.rotate_x(-event.relative.y * mouse_sensitivity)

			# 3. Clamp the camera so you don't do a backflip
			$Body/Head.rotation.x = clamp($Body/Head.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	
func _input(event):
	# CRITICAL GUARD: If this isn't MY character, ignore all inputs!
	if not is_multiplayer_authority(): return
	
	
	# If I press Escape, give me my mouse back!
	if event.is_action_pressed("ui_cancel"): # 'ui_cancel' is usually the Esc key
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# If I click the screen, grab the mouse again
	if event is InputEventMouseButton and event.pressed:
		if is_multiplayer_authority():
			var is_ui_open = (current_ui != null and is_instance_valid(current_ui)) or ($PlayerUI/InventoryUI != null and $PlayerUI/InventoryUI.visible)
			if not is_ui_open:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		is_third_person = !is_third_person
		_apply_camera_mode()

	if event.is_action_pressed("jump") and not is_typing:
		jump_queued = true
	
	if event.is_action_pressed("inventory"):
		toggle_inventory()
	
	if event.is_action_pressed("interact"): # You define "interact" in Input Map (e.g., 'E' key)
		if not is_multiplayer_authority(): return
		#print("pressed interact;")

		# Allow releasing the cart anytime we are driving it
		var carts = get_tree().get_nodes_in_group("carts")
		for c in carts:
			if c.get("driver_id") == multiplayer.get_unique_id():
				_rpc_toggle_cart_grab.rpc_id(1, c.get_path())
				return

		if carried_item == null:
			check_interaction()
		else:
			# If we hold an item, but look at a storage chest, try to deposit it
			var potential_target = get_interaction_target()
			if potential_target:
				if potential_target.has_method("deposit_item"):
					check_interaction()
				elif potential_target.has_meta("is_cart_basket"):
					check_interaction()
				else:
					var tool = get_held_tool()

					# If we have a shovel/tool and are near a treasure...
					if tool and tool.can_interact_with(current_treasure):
						tool.use_tool(current_treasure)
					# ELSE IF we are looking at a treasure but NOT close enough to dig yet...
					#elif current_treasure != null:
					#	print("Too far to dig, doing nothing (prevents accidental drop)")
					# ONLY drop if we aren't trying to use a tool on a valid target
					else:
						drop_item()
			else:
				var tool = get_held_tool()

				# If we have a shovel/tool and are near a treasure...
				if tool and tool.can_interact_with(current_treasure):
					tool.use_tool(current_treasure)
				# ELSE IF we are looking at a treasure but NOT close enough to dig yet...
				#elif current_treasure != null:
				#	print("Too far to dig, doing nothing (prevents accidental drop)")
				# ONLY drop if we aren't trying to use a tool on a valid target
				else:
					drop_item()
		
		
	if event.is_action_pressed("rotate_item_right"):
		# Rotate by 15 degrees clockwise
		rotation_offset += deg_to_rad(15)
		
	if event.is_action_pressed("rotate_item_left"):
		# Rotate by 15 degrees counter-clockwise
		rotation_offset -= deg_to_rad(15)
			
	if event.is_action_pressed("alt_interact"):
		if not is_multiplayer_authority(): return

		if current_furniture != null:
			leave_furniture()
		elif carried_item == null:
			var target = get_interaction_target()
			if target and target is Item and target.has_method("alt_interact"):
				target.alt_interact(self)

	# NEW: Press Left Click (or a new 'throw' action) to yeet!
	if event.is_action_pressed("throw") : 
		if not is_multiplayer_authority(): return
		if carried_item != null:
			throw_item()
			
			


func check_interaction():
	if not can_interact_here(): return
	if not is_multiplayer_authority(): return
	
	var target = get_interaction_target()
	if target:
		if target.has_method("deposit_item"):
		# Scenario A: We are holding an item -> STORE IT
			if carried_item != null:
				# Tell the Server to do the storage math
				_rpc_request_deposit.rpc_id(1, target.get_path(), carried_item.get_path())
				# Drop it locally so our hand is empty
				carried_item = null 
				#_remove_ghost()
			
			# Scenario B: Our hands are empty -> OPEN UI
			else:
				if target.has_method("interact"):
					target.interact(self)

		elif target.has_method("interact"):
			target.interact(self)
		
		# Specific logic for carts
		elif target.has_meta("is_cart_handle"):
			if carried_item == null:
				var cart_node = target.get_meta("cart_node")
				_rpc_toggle_cart_grab.rpc_id(1, cart_node.get_path())
		elif target.has_meta("is_cart_basket"):
			if carried_item != null:
				var cart_node = target.get_meta("cart_node")

				# We allow "drop" even if can_place is false because we're interacting
				# Temporarily force can_place true to bypass standard drop block
				can_place = true
				_rpc_request_cart_deposit.rpc_id(1, cart_node.get_path(), carried_item.get_path())
				drop_item()
				
		# NEW GUARD: If someone else is already the boss of this item and it's 'frozen' (held), ignore it!
		elif target is Item and target.freeze == true:
			print("Someone is already holding this!")
			return

		# ... rest of your existing logic (Crates, etc.)
		elif target.is_in_group("interactables"):
			pick_up(target)


func pick_up(item):
	if not is_multiplayer_authority(): return
	
	if item == null:
		return

	# Check if we are driving any cart. If so, don't allow pick up.
	# We'll just look around if there's any cart where we are the driver.
	# Or, since we only need to not take items while holding the cart, we can add a check.
	# Is the best way to get the root's children and check carts?
	var carts = get_tree().get_nodes_in_group("carts")
	for c in carts:
		if c.get("driver_id") == multiplayer.get_unique_id():
			print("CANNOT PICK UP: You are driving a cart!")
			return

	if item.freeze == true and item.get_multiplayer_authority() != multiplayer.get_unique_id():
		# Check if it's locked to a cart. If so, let's unlock it and take it.
		# Note: locked_to_cart is a server-side only variable in item_logic.
		# However, if it's a cart item, its freeze state might be true and authority might be server(1).
		# Let's request the server to unlock it.
		if item.get_multiplayer_authority() == 1:
			# Potentially locked to cart, try to pick it up anyway
			if item.has_method("request_unlock_from_cart"):
				item.request_unlock_from_cart.rpc_id(1)
		else:
			print("CANNOT PICK UP: Someone else is already the boss of this!")
			return
	
	if item is RigidBody3D:
		item.freeze = false
	
	var my_id = multiplayer.get_unique_id()
	
	# 1. TELL THE WORLD FIRST
	# This triggers the 'sync_authority' function on EVERYONE'S computer.
	if item.has_method("sync_authority"):
		#print("sync_auth found")
		item.sync_authority.rpc(my_id,true)
	
	# 2. WAIT: Give the network one physics frame to process the RPC
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	
	
	if item.get_multiplayer_authority() != my_id:
		print("Authority not ready yet, skipping pick_up...")
		return
	
	if item.get_multiplayer_authority() == multiplayer.get_unique_id():
		carried_item = item
		placement_ray.add_exception(item)
		
		# If it's a naturally spawned item, mark it as claimed by a player so it gets saved
		if "is_autospawned" in carried_item:
			carried_item.is_autospawned = false

		if carried_item.has_method("set_ghost_appearance") and get_held_tool() == null:
			carried_item.set_ghost_appearance(true)
		
		# THE FIX: Tell the Synchronizer to stop sending position updates
		# while we are manually controlling the transform.
		if item.has_node("MultiplayerSynchronizer"):
			item.get_node("MultiplayerSynchronizer").set_process(false)
			item.get_node("MultiplayerSynchronizer").set_physics_process(false)
			
		
		# 1. DISABLE SYNC: Stop the network from fighting your manual movement
		var sync = carried_item.get_node_or_null("MultiplayerSynchronizer")
		if sync:
			sync.set_process(false)
			sync.set_physics_process(false)
		
		# 3. PHYSICS & TOP LEVEL: 
		# Setting top_level = true means the item moves in Global Space, 
		# not "relative" to your hand. This is essential for the Ghost Preview.
		carried_item.freeze = true
		
		# 4. INITIAL SNAP: Put it at the hand's position immediately
		if is_third_person:
			carried_item.global_position = global_position + (global_transform.basis.z * -1.0) + Vector3(0, 1.0, 0)
			carried_item.global_rotation = Vector3(0, self.global_rotation.y, 0)
		else:
			carried_item.global_transform = hand.global_transform

	#print("SUCCESS: Picked up ", item.name)

	# Handle your tool/treasure logic here...
	if item.has_method("set_active_treasure") and current_treasure != null:
		item.set_active_treasure(current_treasure)


func drop_item():
	if not is_multiplayer_authority(): return
	if not can_place: return
	
	carried_item.visible = true
	placement_ray.remove_exception(carried_item)
	tp_placement_ray.remove_exception(carried_item)
	
	# Stop tool logic
	var tool = get_held_tool()
	if tool: 
		tool.update_proximity(null)
	
	
	var item = carried_item
	
	if is_instance_valid(carried_item):
		if carried_item.has_method("set_ghost_appearance"):
			carried_item.set_ghost_appearance(false)
		
			
	carried_item = null
	rotation_offset = 0.0
	
	var final_pos = item.global_position
	var final_rot = item.global_rotation.y
	
	if item is RigidBody3D:
		item.freeze = false
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		# Snap it one last time to be sure
		item.global_position = final_pos
		item.global_rotation.y = final_rot
	
	# 2. KEEP authority as yourself! 
	# Only unfreeze it, but don't give it back to ID 1.
	item.sync_authority.rpc(multiplayer.get_unique_id(), false, Vector3.ZERO, final_pos, final_rot)
	
	#print("Dropped ", item.name)


func throw_item():
	if not is_multiplayer_authority() or carried_item == null: return 
	if not can_place: return
	
	if is_instance_valid(carried_item):
		if carried_item.has_method("set_ghost_appearance"):
			carried_item.set_ghost_appearance(false)
	
	var tool = get_held_tool()
	if tool:
		tool.update_proximity(null)
		

	
	var item = carried_item
	carried_item = null # This stops the _process snap-to-hand IMMEDIATELY
	item.scale = Vector3.ONE

	
	# 1. CALCULATE DATA
	var launch_dir = Vector3.ZERO
	if is_third_person:
		# Use character body forward
		launch_dir = (-global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
		item.global_position = global_position + (launch_dir * 1.0) + Vector3(0, 1.0, 0)
	else:
		launch_dir = (-hand.global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
		item.global_position = hand.global_position + (launch_dir * 0.5)

	var final_velocity = launch_dir * THROW_FORCE
	
	# 3. THE "DE-PARENTING" WAIT
	# We wait for the physics engine to acknowledge the item is no longer 
	# being moved by your global_transform snap in _process.
	await get_tree().physics_frame
	
	# 4. ATOMIC RPC
	var my_id = multiplayer.get_unique_id()
	item.sync_authority.rpc(my_id, false, final_velocity,Vector3.ZERO,0.0)
	
	# 5. HANDOVER
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(item):
			# Hand back to server (1) so anyone can pick it up
			item.sync_authority.rpc(1, false, item.linear_velocity, item.global_position, item.global_rotation.y)
	)



func apply_eye_color(c):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = c
	# Assuming your eyes are named 'Eye1' and 'Eye2'
	$Body/Head/Eye.set_surface_override_material(0, mat)
	$Body/Head/Eye2.set_surface_override_material(0, mat)
	
	
	
@rpc("any_peer", "call_local")
func receive_message(text: String):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return 
		
	$Nickname.text = text
	$Nickname.modulate = Color.YELLOW # Highlight the text
	
	# Wait 4 seconds
	await get_tree().create_timer(4.0).timeout
	
	# Reset back to the original player name
	$Nickname.text = name
	$Nickname.modulate = Color.WHITE


func _on_catch_zone_body_entered(body):
	
	
	# If I'm already holding something, I can't catch another thing
	if carried_item != null or catch_cooldown: return
	
	# Only catch if it's a throwable object and NOT currently held by anyone
	if body.is_in_group("interactables") and body is RigidBody3D:
		# Check if the object is 'flying' (not frozen)
		if body.freeze == false:
			if body.linear_velocity.length() > 2.0:
				print("Auto-Catch!")
				pick_up(body)
				
				
				
				
func get_held_tool() -> Tool:
	if carried_item:
		# Search MeshAnchor for any script
		var anchor = carried_item.get_node_or_null("MeshAnchor")
		if anchor and anchor.get_child_count() > 0:
			var potential_tool = anchor.get_child(0)
			# Only return it if it actually has tool-like functions
			if potential_tool.has_method("update_proximity"):
				return potential_tool
	
	# If it's just a shell, return null so the player knows 
	# there's nothing to "beep" with.
	return null
	
# Helper function to get ALL children (add this to player script or use a loop)
func _find_tool_recursive(node) -> Tool:
	if node is Tool:
		return node
	for child in node.get_children():
		var found = _find_tool_recursive(child)
		if found: return found
	return null
	
	
func set_near_treasure(treasure, is_near: bool):
	# 1. Update the player's knowledge
	if is_near:
		if not nearby_treasures.has(treasure):
			nearby_treasures.append(treasure)
	else:
		nearby_treasures.erase(treasure)
	
	# 2. Update the tool's knowledge
	var tool = get_held_tool()
	if tool:
		print("PLAYER: Found tool: ", tool.name)
	#else:
		#print("PLAYER: No tool found in carried_item!")
		
	if tool:
		tool.update_proximity(current_treasure)


func teleport(target_pos: Vector3, target_rot: Vector3 = Vector3.ZERO):
	if is_multiplayer_authority():
		global_position = target_pos
		global_rotation.y = target_rot.y
	else:
		_rpc_teleport.rpc_id(get_multiplayer_authority(), target_pos, target_rot)

@rpc("any_peer", "call_local")
func _rpc_teleport(target_pos: Vector3, target_rot: Vector3):
	global_position = target_pos
	global_rotation.y = target_rot.y


func _process(_delta):
	_sync_highlight_camera()
	if not is_multiplayer_authority(): return
	
	
	update_action_ui()
	
	if carried_item:
		update_ghost_preview()
		
	
	
	nearby_treasures = nearby_treasures.filter(func(t): return is_instance_valid(t))
	
	var nearest_treasure = null
	var min_dist = 9999.0

	for t in nearby_treasures:
		var d = global_position.distance_to(t.global_position)
		if d < min_dist:
			min_dist = d
			nearest_treasure = t
			
	current_treasure = nearest_treasure
	
	if current_treasure:
		# Check if we are in the 'DiggingCollision' (the small one)
		var dist = global_position.distance_to(current_treasure.global_position)
		
		if dist < DIG_DIST:
			if not can_dig:
				can_dig = true
				print("UI: PRESS 'E' TO DIG!")
		else:
			can_dig = false
		
		var tool = get_held_tool()
		if tool:
			tool.update_proximity(current_treasure)
			
			
			
			
			
func update_ghost_preview():
	if not carried_item: return
	
	# If it's a tool, keep it in hand (no ghost placement)
	if get_held_tool() != null:
		carried_item.global_transform = hand.global_transform
		return
	
	var active_placement_ray = placement_ray
	if is_third_person:
		active_placement_ray = tp_placement_ray

	# Use the RayCast to find the floor or other items
	if active_placement_ray.is_colliding():
		var hit_point = active_placement_ray.get_collision_point()
		
		# 1. Calculate the Y-offset (distance to 'feet')
		var y_offset = 0.0
		var min_y = 0.0
		var found_collision = false
		
		# Helper to process a node's AABB in the item's local space
		var item_inv_trans = carried_item.global_transform.affine_inverse()
		
		# Find all CollisionShape3D nodes (recursive) under MeshAnchor
		var search_nodes = []
		var anchor = carried_item.get_node_or_null("MeshAnchor")
		if anchor:
			search_nodes = anchor.find_children("*", "CollisionShape3D", true, false)
			
		for node in search_nodes:
			if node.shape:
				var shape_mesh = node.shape.get_debug_mesh()
				if shape_mesh:
					var shape_aabb = shape_mesh.get_aabb()
					# Transform AABB to item's local space
					var local_trans = item_inv_trans * node.global_transform
					var final_aabb = local_trans * shape_aabb
					
					if not found_collision:
						min_y = final_aabb.position.y
						found_collision = true
					else:
						min_y = min(min_y, final_aabb.position.y)
		
		if found_collision:
			y_offset = -min_y
		
		# Apply scale just in case the parent is scaled
		y_offset *= carried_item.scale.y
		
		# Check if we are looking at a cart basket (via raycast OR interaction target)
		var looking_at_cart = false
		if active_placement_ray.get_collider() and active_placement_ray.get_collider().has_meta("is_cart_basket"):
			looking_at_cart = true
		else:
			var interact_target = get_interaction_target()
			if interact_target and interact_target.has_meta("is_cart_basket"):
				looking_at_cart = true

		if looking_at_cart:
			# Hide ghost and block standard drop placement
			if carried_item.has_method("set_ghost_appearance"):
				carried_item.set_ghost_appearance(false)
			carried_item.visible = false
			can_place = false
		else:
			# Standard placement
			carried_item.visible = true
			if carried_item.has_method("set_ghost_appearance"):
				carried_item.set_ghost_appearance(true)

			# 2. GLIDE: Set position at hit point + feet offset
			carried_item.global_position = hit_point + Vector3(0, y_offset, 0)

			# 3. ROTATION: Keep it upright and apply scroll offset
			carried_item.global_rotation = Vector3(0, self.global_rotation.y + rotation_offset, 0)

			# Validate placement regarding tent state
			if get_tent_for_position(hit_point) == get_tent_for_position(global_position):
				can_place = true
			else:
				can_place = false
	else:
		# Fallback: If not looking at a surface, keep item in hand
		if is_third_person:
			# Fallback for third person, put it slightly in front of player at height 1.0
			carried_item.global_position = global_position + (global_transform.basis.z * -1.0) + Vector3(0, 1.0, 0)
			carried_item.global_rotation = Vector3(0, self.global_rotation.y + rotation_offset, 0)
		else:
			carried_item.global_transform = hand.global_transform
		can_place = true

	if carried_item.has_method("set_ghost_valid"):
		carried_item.set_ghost_valid(can_place)
	

func update_action_ui():
	if not is_multiplayer_authority(): 
		action_label.hide() # Hide UI for other players' versions of you
		return

	action_label.show()
	var target_text = ""
	var highlight_target = null

	# Are we currently driving the cart?
	var currently_driving_cart = false
	var carts = get_tree().get_nodes_in_group("carts")
	for c in carts:
		if c.get("driver_id") == multiplayer.get_unique_id():
			currently_driving_cart = true
			highlight_target = c
			break

	if current_ui != null and is_instance_valid(current_ui):
		target_text = ""
		highlight_target = null
	elif currently_driving_cart:
		target_text = "[E] Release Cart"
	elif current_furniture != null and is_instance_valid(current_furniture):
		target_text = "[R] Get up"
		highlight_target = current_furniture
	elif carried_item == null:
		# Use your existing interaction check (Raycast or Shapecast)
		var potential_item = get_interaction_target() 
		
		if potential_item:
			highlight_target = potential_item
			if potential_item is Item:
				target_text = "[E] Take " + potential_item.display_name
				if potential_item.has_method("get_alt_interaction_text"):
					var alt_txt = potential_item.get_alt_interaction_text()
					if alt_txt != "":
						target_text += " " + alt_txt
			elif potential_item.has_method("get_interaction_text"):
				target_text = potential_item.get_interaction_text()
			elif potential_item.has_method("deposit_item"):
				target_text = "[E] Open Storage"
			elif potential_item.has_method("interact"):
				target_text = "[E] Interact"
			elif potential_item.has_meta("is_cart_handle"):
				var cart_node = potential_item.get_meta("cart_node")
				if cart_node.driver_id == 0:
					target_text = "[E] Take Cart"
					highlight_target = cart_node
	else:
		var potential_target = get_interaction_target()
		if potential_target:
			if potential_target.has_method("deposit_item"):
				target_text = "[E] Store " + carried_item.display_name
				highlight_target = potential_target
			elif potential_target.has_meta("is_cart_basket"):
				target_text = "[E] Deposit in cart"
				highlight_target = potential_target.get_meta("cart_node")
			else:
				var tool = get_held_tool()
				if tool and tool.can_interact_with(current_treasure):
					target_text = "[E] " + tool.get_action_name()
					highlight_target = current_treasure
				else:
					if can_place:
						target_text = "[E] Drop " + carried_item.display_name
					else:
						target_text = "You can't place it here"
		else:
			var tool = get_held_tool()
			if tool and tool.can_interact_with(current_treasure):
				target_text = "[E] " + tool.get_action_name()
				highlight_target = current_treasure
			else:
				if can_place:
					target_text = "[E] Drop " + carried_item.display_name
				else:
					target_text = "You can't place it here"

	if target_text == "" or target_text == "You can't place it here":
		_update_highlight(null)
	else:
		_update_highlight(highlight_target)

	# Only update if the text changed to avoid flickering
	if action_label.text != target_text:
		action_label.text = target_text
		
		# Simple Fade Effect
		var tween = create_tween()
		if target_text == "":
			tween.tween_property(action_label, "modulate:a", 0.0, 0.1)
		else:
			action_label.modulate.a = 0.0 # Start from invisible
			tween.tween_property(action_label, "modulate:a", 1.0, 0.2)
	


func use_furniture(furniture_node: Node3D):
	if not is_multiplayer_authority(): return
	if carried_item != null:
		drop_item()
	current_furniture = furniture_node
	# Optional: Disable collision mask if needed so player doesn't pop out
	set_collision_mask_value(1, false)
	is_sitting = true
	_update_sit_visuals.rpc(true)

func leave_furniture():
	if not is_multiplayer_authority(): return
	if current_furniture != null:
		if current_furniture.has_method("leave"):
			current_furniture.leave(self)
		current_furniture = null
		# Optional: re-enable collision mask
		set_collision_mask_value(1, true)
		is_sitting = false
		_update_sit_visuals.rpc(false)
		# Hop them up slightly so they don't clip
		global_position.y += 0.5

@rpc("call_local", "reliable")
func _update_sit_visuals(is_sitting: bool):
	if is_sitting:
		if state_sit: state_sit.show()
		if state_stand: state_stand.hide()
	else:
		if state_sit: state_sit.hide()
		if state_stand: state_stand.show()

func get_interaction_target():
	var active_shapecast = $Body/Head/Camera3D/InteractionShape
	if is_third_person:
		active_shapecast = tp_shapecast

	if active_shapecast.is_colliding():
		var collision_count = active_shapecast.get_collision_count()

		var my_tent = get_tent_for_position(global_position)

		if carried_item == null:
			# If NOT carrying an item, prioritize picking up items so large zones don't block them
			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if collider is Item:
					if get_tent_for_position(collider.global_position) == my_tent:
						return collider

			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if get_tent_for_position(collider.global_position) != my_tent: continue

				if collider.has_method("deposit_item") or collider.has_method("get_interaction_text") or collider.has_method("interact"):
					return collider
				if collider.has_meta("is_cart_handle") or collider.has_meta("is_cart_basket"):
					return collider
		else:
			# If CARRYING an item, prioritize containers (chest, pot, cart basket)
			# so we can easily deposit even if the container is full of other items
			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if get_tent_for_position(collider.global_position) != my_tent: continue

				if collider.has_method("deposit_item") or collider.has_meta("is_cart_basket"):
					return collider

			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if get_tent_for_position(collider.global_position) != my_tent: continue

				# Fallback to general interaction (maybe a tool interact like digging, or alt interact)
				if collider is Item or collider.has_method("interact") or collider.has_meta("is_cart_handle"):
					return collider

	return null


func add_to_collection(data: ItemData):
	var n = data.name
	if collection.has(n):
		collection[n]["count"] += 1
	else:
		collection[n] = {"resource": data, "count": 1}
	
	collection_updated.emit(collection)
	
	if is_multiplayer_authority():
		$PlayerUI/NotificationArea.display_message("Found: " + data.display_name + "!")

func toggle_inventory():
	if not is_multiplayer_authority(): return
	
	var inv_ui = $PlayerUI/InventoryUI 
	inv_ui.visible = !inv_ui.visible
	
	if inv_ui.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# FORCE A REFRESH SO IT'S NOT EMPTY
		inv_ui.refresh_ui(collection) 
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func get_tent_for_position(pos: Vector3) -> Node:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsPointQueryParameters3D.new()
	query.position = pos
	query.collision_mask = 8 # Tent Area3D layer
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results = space_state.intersect_point(query)
	for res in results:
		if res.collider is Area3D:
			var tent = res.collider.get_parent()
			if tent.has_method("can_player_modify"):
				return tent
	return null

func can_interact_here() -> bool:
	# 1. Get all overlapping areas at the player's feet
	# (Assuming you have a small Area3D on the player to detect 'Zones')
	var zones = $ZoneDetector.get_overlapping_areas()
	
	for zone in zones:
		var tent = zone.get_parent()
		if tent.has_method("can_player_modify"):
			# If the bouncer says NO, we return false
			if not tent.can_player_modify(multiplayer.get_unique_id()):
				print("Hey! This isn't your tent!")
				return false
	return true
	
	
	
	# Send the request to the Server
@rpc("any_peer", "call_local")
func _rpc_request_deposit(chest_path: NodePath, item_path: NodePath):
	if not multiplayer.is_server(): return
	
	var chest = get_node_or_null(chest_path)
	var item = get_node_or_null(item_path)
	var sender_id = multiplayer.get_remote_sender_id()
	
	if chest and item:
		chest.deposit_item(item, sender_id)
		
		
		
func open_ui(ui_instance: Control) -> bool:
	# Don't open it if it's already open
	if current_ui != null and is_instance_valid(current_ui):
		ui_instance.queue_free()
		return false
		
	# 1. Assign the UI
	current_ui = ui_instance
	add_child(current_ui)
	
	# 2. Unlock the mouse so the player can click the grid
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


@rpc("any_peer", "call_local")
func _rpc_toggle_cart_grab(cart_path: NodePath):
	if not multiplayer.is_server(): return
	
	var cart = get_node_or_null(cart_path)
	var my_player = self # This script is directly on the player
	var my_id = multiplayer.get_remote_sender_id()
	
	if cart:
		if cart.driver_id == my_id:
			cart.release_cart()
		else:
			cart.grab_cart(my_player, my_id)
			

@rpc("any_peer", "call_local")
func receive_money(amount: int):
	if not is_multiplayer_authority():
		return
	money += amount
	save_money()
	update_money_ui()
	show_floating_money(amount)

func update_money_ui():
	var money_label = $PlayerUI/MoneyLabel
	if money_label:
		money_label.text = "Money: $" + str(money)

func show_floating_money(amount: int):
	var floating_label = Label.new()
	floating_label.text = "+$" + str(amount)
	floating_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Green color
	floating_label.add_theme_font_size_override("font_size", 24)

	$PlayerUI.add_child(floating_label)

	# Position it somewhat near the main money label
	var start_pos = Vector2(20, 60)
	if $PlayerUI/MoneyLabel:
		start_pos = $PlayerUI/MoneyLabel.position + Vector2(0, 30)

	floating_label.position = start_pos

	var tween = create_tween()
	# Float upwards and fade out
	tween.tween_property(floating_label, "position", start_pos + Vector2(0, -50), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, 1.5)

	tween.tween_callback(floating_label.queue_free)

			
@rpc("any_peer", "call_local")
func _rpc_request_cart_deposit(cart_path: NodePath, item_path: NodePath):
	# Security check: Only the Server manages the math
	if not multiplayer.is_server(): return
	
	var cart = get_node_or_null(cart_path)
	var item = get_node_or_null(item_path)
	
	if cart != null and item != null:
		if cart.has_method("deposit_item_cart"):
			cart.deposit_item_cart(item)

# --- HIGHLIGHT LOGIC ---
const OUTLINE_MATERIAL = preload("res://resources/materials/post_process_outline.tres")

# Visual Layer 20 is reserved for highlighted objects (bitwise: 1 << 19)
const HIGHLIGHT_LAYER = 1 << 19

var _highlight_viewport: SubViewport
var _highlight_camera: Camera3D
var _highlight_container: SubViewportContainer
var _highlight_tween: Tween = null
var _highlight_meshes: Array[MeshInstance3D] = []

func _ready_highlight_system():
	# Build the Post-Processing Rig and attach it to the screen UI
	_highlight_container = SubViewportContainer.new()
	_highlight_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_container.stretch = true # Ensure viewport perfectly matches screen

	# Duplicate material so alpha_multiplier fading doesn't affect other players globally
	_highlight_container.material = OUTLINE_MATERIAL.duplicate()

	_highlight_viewport = SubViewport.new()
	_highlight_viewport.transparent_bg = true
	_highlight_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_highlight_camera = Camera3D.new()
	# ONLY see layer 20
	_highlight_camera.cull_mask = HIGHLIGHT_LAYER
	_highlight_camera.environment = Environment.new()
	_highlight_camera.environment.background_mode = Environment.BG_COLOR
	_highlight_camera.environment.bg_color = Color(0, 0, 0, 0)

	_highlight_viewport.add_child(_highlight_camera)
	_highlight_container.add_child(_highlight_viewport)

	# Add it underneath other UI elements if possible, or straight to PlayerUI
	if has_node("PlayerUI"):
		$PlayerUI.add_child(_highlight_container)
		$PlayerUI.move_child(_highlight_container, 0) # Render behind crosshair/text

func _sync_highlight_camera():
	if not _highlight_camera: return

	var main_cam = $Body/Head/Camera3D
	if is_third_person:
		main_cam = tp_camera

	if main_cam and main_cam.current:
		_highlight_camera.global_transform = main_cam.global_transform
		_highlight_camera.fov = main_cam.fov
		_highlight_camera.size = main_cam.size

func _get_meshes_recursive(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_get_meshes_recursive(child, meshes)

func _update_highlight(target_node: Node) -> void:
	if _highlighted_node == target_node:
		return

	if _highlighted_node != null and is_instance_valid(_highlighted_node):
		_fade_highlight(false)
		# We NO LONGER immediately strip the layer bit here!
		# It must happen at the end of the fade_out tween to remain visible while fading.

	_highlighted_node = target_node

	if _highlighted_node != null and is_instance_valid(_highlighted_node):
		# Immediately clear old highlight meshes if targeting a new object
		# while a previous fadeout was incomplete to prevent multiple highlights.
		if _highlight_meshes.size() > 0:
			for m in _highlight_meshes:
				if is_instance_valid(m):
					m.layers &= ~HIGHLIGHT_LAYER
		_highlight_meshes.clear()

		_get_meshes_recursive(_highlighted_node, _highlight_meshes)
		# Add the highlight layer bit to new meshes
		for m in _highlight_meshes:
			if is_instance_valid(m):
				m.layers |= HIGHLIGHT_LAYER

		_fade_highlight(true)

func _fade_highlight(fade_in: bool) -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()

	_highlight_tween = create_tween()
	var mat = _highlight_container.material # Target the local instance material

	if fade_in:
		_highlight_tween.tween_property(mat, "shader_parameter/alpha_multiplier", 1.0, 0.2)
	else:
		_highlight_tween.tween_property(mat, "shader_parameter/alpha_multiplier", 0.0, 0.2)

		# Now that we're completely faded out, strip the highlight bit so
		# the secondary camera stops rendering them unnecessarily.
		_highlight_tween.tween_callback(func():
			for m in _highlight_meshes:
				if is_instance_valid(m):
					m.layers &= ~HIGHLIGHT_LAYER
			_highlight_meshes.clear()
		)