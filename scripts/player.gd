extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const THROW_FORCE = 8.0
const DIG_DIST = 1.5

@onready var shapecast = $Body/Head/Camera3D/InteractionShape
@onready var hand = $Body/Head/Camera3D/HandMarker
@onready var action_label = $PlayerUI/ActionLabel
@onready var placement_ray = $Body/Head/Camera3D/PlacementRay


@export var mouse_sensitivity = 0.002

# This variable will be synced across the network
@export var eye_color: Color = Color.BLUE


var rotation_offset: float = 0.0
@export var rotation_speed: float = 0.5 # How fast it rotates with scroll


var is_typing = false
var carried_item = null
var catch_cooldown = false
var last_hovered_item = null

var nearby_treasures: Array[Node3D] = [] # Change current_treasure to an Array
var current_treasure = null # This will now be the NEAREST one
var can_dig = false
var jump_queued = false


# Stores item names and their counts: {"Pink Shell": 3, "Old Coin": 1}
var collection = {}

# Signal to tell the UI to refresh
signal collection_updated(new_collection)

func _enter_tree() -> void:
	pass

func _ready():
	
	# WAIT for the spawner to actually name the node (e.g., "1" or "2384923")
	# If the name is "Player" or "@Player", authority will fail.
	
	
	await get_tree().process_frame
	
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)
	
	$Nickname.text = name
	
	
	# RE-EVALUATE authority after the name change
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())
		
	if is_multiplayer_authority():
		$Body/Head/Camera3D.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$PlayerUI.show()
		
		set_physics_process(true)
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		print("SUCCESS: I am the BOSS of ", name)
		
		eye_color = Color(randf(), randf(), randf()) # Random RGB
		apply_eye_color(eye_color)
		
		
	else:
		# THIS IS SOMEONE ELSE: Turn off their camera on my screen
		$Body/Head/Camera3D.current = false
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
		
	# Connect the 'Catch' signal
	$Body/Head/Camera3D/CatchZone.body_entered.connect(_on_catch_zone_body_entered)
	


func _physics_process(delta: float) -> void:
	
	if not is_multiplayer_authority() or is_typing: return
	
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
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()
	
	
func _unhandled_input(event):
	
	# IF THIS IS NOT MY CHARACTER, DO NOT MOVE THE CAMERA/LASER
	if not is_multiplayer_authority() or is_typing: return
	
	# This checks if the mouse is moving
	if event is InputEventMouseMotion:
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
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("jump") and not is_typing:
		jump_queued = true
	
	if event.is_action_pressed("inventory"):
		toggle_inventory()
	
	if event.is_action_pressed("interact"): # You define "interact" in Input Map (e.g., 'E' key)
		if not is_multiplayer_authority(): return
		print("pressed interact;")
		if carried_item == null:
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
		
		
	if event.is_action_pressed("rotate_item_right"):
		# Rotate by 15 degrees clockwise
		rotation_offset += deg_to_rad(15)
		
	if event.is_action_pressed("rotate_item_left"):
		# Rotate by 15 degrees counter-clockwise
		rotation_offset -= deg_to_rad(15)
			
	# NEW: Press Left Click (or a new 'throw' action) to yeet!
	if event.is_action_pressed("throw") or event.is_action_pressed("ui_select"): 
		if not is_multiplayer_authority(): return
		if carried_item != null:
			throw_item()
			
			


func check_interaction():
	if not is_multiplayer_authority(): return
	if shapecast.is_colliding():
		var target = shapecast.get_collider(0)
		
		# NEW GUARD: If someone else is already the boss of this item and it's 'frozen' (held), ignore it!
		if target is Item and target.freeze == true:
			print("Someone is already holding this!")
			return

		# ... rest of your existing logic (Crates, etc.)
		if target.has_method("interact"):
			target.interact(self)
		elif target.is_in_group("interactables"):
			pick_up(target)


func pick_up(item):
	if not is_multiplayer_authority(): return
	
	if item == null:
		return
	
	if item.freeze == true and item.get_multiplayer_authority() != multiplayer.get_unique_id():
		print("CANNOT PICK UP: Someone else is already the boss of this!")
		return
	
	if item is RigidBody3D:
		item.freeze = false
	
	var my_id = multiplayer.get_unique_id()
	
	# 1. TELL THE WORLD FIRST
	# This triggers the 'sync_authority' function on EVERYONE'S computer.
	if item.has_method("sync_authority"):
		print("sync_auth found")
		item.sync_authority.rpc(my_id,true)
	
	# 2. WAIT: Give the network one physics frame to process the RPC
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	
	
	if item.get_multiplayer_authority() != my_id:
		print("Authority not ready yet, skipping pick_up...")
		return
	
	if item.get_multiplayer_authority() == multiplayer.get_unique_id():
		carried_item = item
		item.top_level = true
		placement_ray.add_exception(item)
		
		if carried_item.has_method("set_ghost_appearance") and get_held_tool() == null:
			carried_item.set_ghost_appearance(true)
		
		# THE FIX: Tell the Synchronizer to stop sending position updates
		# while we are manually controlling the transform.
		if item.has_node("MultiplayerSynchronizer"):
			item.get_node("MultiplayerSynchronizer").set_process(false)
			item.get_node("MultiplayerSynchronizer").set_physics_process(false)
		
		if item.has_node("CollisionShape3D"):
			item.get_node("CollisionShape3D").disabled = true
			
		
		# 1. DISABLE SYNC: Stop the network from fighting your manual movement
		var sync = carried_item.get_node_or_null("MultiplayerSynchronizer")
		if sync:
			sync.set_process(false)
			sync.set_physics_process(false)
		
		# 2. DISABLE COLLISION: So it doesn't hit your feet while carrying
		if carried_item.has_node("CollisionShape3D"):
			carried_item.get_node("CollisionShape3D").disabled = true
		
		# 3. PHYSICS & TOP LEVEL: 
		# Setting top_level = true means the item moves in Global Space, 
		# not "relative" to your hand. This is essential for the Ghost Preview.
		carried_item.freeze = true
		carried_item.top_level = true 
		
		# 4. INITIAL SNAP: Put it at the hand's position immediately
		var original_scale = carried_item.scale
		carried_item.global_transform = hand.global_transform
		carried_item.scale = original_scale

	print("SUCCESS: Picked up ", item.name)

	# Handle your tool/treasure logic here...
	if item.has_method("set_active_treasure") and current_treasure != null:
		item.set_active_treasure(current_treasure)


func drop_item():
	if not is_multiplayer_authority(): return
	
	placement_ray.remove_exception(carried_item)
	
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
	
	item.top_level = false
	if item.has_node("CollisionShape3D"):
		item.get_node("CollisionShape3D").disabled = false
		
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
	
	print("Dropped ", item.name)


func throw_item():
	if not is_multiplayer_authority() or carried_item == null: return 
	
	var tool = get_held_tool()
	if tool:
		tool.update_proximity(null)
		

	
	var item = carried_item
	carried_item = null # This stops the _process snap-to-hand IMMEDIATELY
	
	if is_instance_valid(carried_item):
		if carried_item.has_method("set_ghost_appearance"):
			carried_item.set_ghost_appearance(false)
	
	# 1. CALCULATE DATA
	var launch_dir = (-hand.global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
	var final_velocity = launch_dir * THROW_FORCE
	
	item.global_position = hand.global_position + (launch_dir * 0.5)
	# 2. PHYSICS PREP
	if item.has_node("CollisionShape3D"):
		item.get_node("CollisionShape3D").disabled = false
	
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
	else:
		print("PLAYER: No tool found in carried_item!")
		
	if tool:
		tool.update_proximity(current_treasure)


func _process(_delta):
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
		var original_scale = carried_item.scale
		carried_item.global_transform = hand.global_transform
		carried_item.scale = original_scale
		return
	
	# Use the RayCast to find the floor or other items
	if placement_ray.is_colliding():
		var hit_point = placement_ray.get_collision_point()
		
		# 1. Calculate the Y-offset (distance to 'feet')
		var y_offset = 0.0
		var total_aabb: AABB = AABB()
		var first_mesh = true
		
		for child in carried_item.find_children("*", "VisualInstance3D"):
			var mesh_aabb = child.get_aabb()
			var child_transform = child.transform
			var world_aabb = child_transform * mesh_aabb
			
			if first_mesh:
				total_aabb = world_aabb
				first_mesh = false
			else:
				total_aabb = total_aabb.merge(world_aabb)
		
		if not first_mesh:
			var box_end: Vector3 = total_aabb.end
			var box_size: Vector3 = total_aabb.size
			var mesh_bottom_y = box_end.y - box_size.y
			y_offset = -mesh_bottom_y
		else:
			y_offset = 0.5
		
		# 2. GLIDE: Set position at hit point + feet offset
		carried_item.global_position = hit_point + Vector3(0, y_offset, 0)
		
		# 3. ROTATION: Keep it upright and apply scroll offset
		carried_item.global_rotation = Vector3(0, self.global_rotation.y + rotation_offset, 0)
		
		# 4. SCALE: Ensure the ghost is actual size (not shrunk by hand scale)
		#carried_item.scale = Vector3.ONE
	else:
		# Fallback: If not looking at a surface, keep item in hand
		var original_scale = carried_item.scale
		carried_item.global_transform = hand.global_transform
		carried_item.scale = original_scale
	

func update_action_ui():
	if not is_multiplayer_authority(): 
		action_label.hide() # Hide UI for other players' versions of you
		return
	# Safety check in case the label isn't found
	var target_text = ""
	if carried_item == null:
		# Use your existing interaction check (Raycast or Shapecast)
		var potential_item = get_interaction_target() 
		
		if potential_item and potential_item is Item:
			target_text = "[E] Take " + potential_item.display_name
	else:
		var tool = get_held_tool()
		if tool :
			print(tool.get_action_name())
			#print("Found tool: ", tool.get_action_name(), " | Target: ", current_treasure)
		if tool and tool.can_interact_with(current_treasure):
			target_text = "[E] " + tool.get_action_name()
		else:
			target_text = "[E] Drop " + carried_item.display_name

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
	


func get_interaction_target():
	# Replace 'shapecast' with the name of your RayCast3D or ShapeCast3D node
	if $Body/Head/Camera3D/InteractionShape.is_colliding():
		var collider = $Body/Head/Camera3D/InteractionShape.get_collider(0)
		# Only return it if it's an item we can actually pick up
		#print("Shapecast met ", shapecast.get_collider(0).name, " on Layer: ", shapecast.get_collider(0).collision_layer)
		if collider is Item:
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
