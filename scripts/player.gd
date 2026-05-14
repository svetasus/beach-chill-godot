extends CharacterBody3D

var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.3 # time between steps



const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const THROW_FORCE = 16.0
const DIG_DIST = 1.5

@export var SWIM_SPEED: float = 3.0
@export var WATER_JUMP_VELOCITY: float = 5.0
@export var WATER_FLOAT_OFFSET: float = -0.3

@onready var shapecast = $Body/Head/Camera3D/InteractionShape
@onready var hand = $Body/Head/Camera3D/HandMarker
@onready var head_item_marker = $Body/Head/HeadItemMarker
@onready var action_label = $PlayerUI/ActionLabel
@onready var hint_label = $PlayerUI/HintLabel
@onready var placement_ray = $Body/Head/Camera3D/PlacementRay
@onready var state_sit = $State_Sit
@onready var state_stand = $State_Stand
@onready var state_swim = $State_Swim

@onready var tp_camera = $Body/SpringArm3D/ThirdPersonCamera
@onready var tp_spring_arm = $Body/SpringArm3D
@onready var tp_shapecast = $ThirdPersonInteractionShape
@onready var tp_placement_ray = $ThirdPersonPlacementRay

@export var is_third_person: bool = false
@export var mouse_sensitivity = 0.002

# This variable will be synced across the network
@export var eye_color: Color = Color.BLUE

# Sync this variable in MultiplayerSynchronizer so late joiners know the state!
@export var is_sitting: bool = false

var rotation_offset: float = 0.0
@export var rotation_speed: float = 0.5 # How fast it rotates with scroll

var current_ui: Control = null

var footstep_iterator : int = 0

var is_typing = false
var carried_items: Array[Node] = [null, null, null, null]
var current_slot_index: int = 0
var carried_item:
	get:
		return carried_items[current_slot_index]
	set(value):
		carried_items[current_slot_index] = value

signal inventory_slots_updated(slots, active_index)

func switch_slot(index: int):
	if index < 0 or index >= carried_items.size(): return
	if current_slot_index == index: return

	var old_item = carried_item
	if is_instance_valid(old_item):
		# Put away the old item
		old_item.visible = false
		if old_item.has_method("set_ghost_appearance"):
			old_item.set_ghost_appearance(false)

		# If it's a tool, stop its logic
		var anchor = old_item.get_node_or_null("MeshAnchor")
		if anchor and anchor.get_child_count() > 0:
			var potential_tool = anchor.get_child(0)
			if potential_tool.has_method("update_proximity"):
				potential_tool.update_proximity(null)

	current_slot_index = index
	var new_item = carried_item

	if is_instance_valid(new_item):
		# Equip the new item
		new_item.visible = true
		if new_item.has_method("set_ghost_appearance") and get_held_tool() == null:
			new_item.set_ghost_appearance(true)

		# It's already frozen from pick_up, so it's ready to snap in _process

	inventory_slots_updated.emit(carried_items, current_slot_index)

var catch_cooldown = false
var last_hovered_item = null

var nearby_treasures: Array[Node3D] = [] # Change current_treasure to an Array
var current_treasure = null # This will now be the NEAREST one
var can_dig = false
var jump_queued = false
var can_place = true
var current_furniture = null
var _highlighted_node = null

var water_areas_count: int = 0
var current_water_surface_height: float = 0.0

# Stores item names and their counts: {"Pink Shell": 3, "Old Coin": 1}
var collection = {}
var items_held = {}
var artifacts_crafted = {}

var money: int = 0

# Signal to tell the UI to refresh
signal collection_updated(new_collection)

func get_save_path() -> String:
	if is_multiplayer_authority():
		return "user://player_money_" + Global.sanitize_filename(Global.account_id) + ".save"
	else:
		return "user://player_money_" + Global.sanitize_filename(str(name)) + ".save"

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
		if hint_label:
			hint_label.hide()
		
		set_physics_process(true)
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		#print("SUCCESS: I am the BOSS of ", name)
		
		eye_color = Color(randf(), randf(), randf()) # Random RGB
		apply_eye_color(eye_color)
		
		load_money()
		update_money_ui()
		inventory_slots_updated.emit(carried_items, current_slot_index)
		var tasks_ui = $PlayerUI/TaskListUI
		if tasks_ui and tasks_ui.has_method("load_tasks"):
			tasks_ui.load_tasks()
		var milestones_ui = $PlayerUI/MilestoneListUI
		if milestones_ui and milestones_ui.has_method("load_milestones"):
			milestones_ui.load_milestones()
		
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


func enter_water(surface_height: float):
	water_areas_count += 1
	current_water_surface_height = max(current_water_surface_height, surface_height)
	if state_swim: state_swim.show()
	if state_stand: state_stand.hide()

func exit_water():
	water_areas_count -= 1
	if water_areas_count <= 0:
		water_areas_count = 0
		current_water_surface_height = 0.0
		
	
	if state_stand: state_stand.show()
	if state_swim: state_swim.hide()

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

	# Determine if we're actually deep enough to be "swimming"
	# WATER_FLOAT_OFFSET is negative (e.g. -0.5), so we add it to the surface height to get the float line.
	var float_line = current_water_surface_height + WATER_FLOAT_OFFSET
	# Only start swimming if we're not on the floor, fulfilling the constraint "if player still in the ground, they shouldn't start to swim"
	var is_swimming = water_areas_count > 0 and global_position.y <= float_line and not is_on_floor()

	# Always add the gravity unless perfectly resting on the floor.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_swimming:
		# Apply buoyancy as an acceleration that fights gravity
		# If the player is below the float line, buoyancy pushes them up.
		var depth = float_line - global_position.y
		# Gravity is pulling down, so buoyancy pushes up with enough force to counteract it plus push towards surface
		var buoyancy_acceleration = depth * 20.0
		var water_drag = 2.0 # How much the water slows vertical movement

		velocity.y += buoyancy_acceleration * delta
		velocity.y -= velocity.y * water_drag * delta

	# Handle jump.
	if jump_queued:
		jump_queued = false
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_swimming:
			# When jumping in water, we set the velocity so the player shoots up.
			# Because buoyancy is now an acceleration (adding force) rather than a rigid lerp,
			# the player will actually move upwards out of the water.
			velocity.y = WATER_JUMP_VELOCITY

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

	var current_speed = SWIM_SPEED if is_swimming else SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		

	if is_on_floor() and direction != Vector3.ZERO:
		footstep_timer += delta
		if footstep_timer >= FOOTSTEP_INTERVAL / (current_speed / SPEED):
			_play_footstep_sound()
			footstep_timer = 0.0
	else:
		footstep_timer = 0.0

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
		if $PlayerUI/CollectionUI != null and $PlayerUI/CollectionUI.visible:
			toggle_collection()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# If I click the screen, grab the mouse again
	if event is InputEventMouseButton and event.pressed:
		if is_multiplayer_authority():
			var is_ui_open = (current_ui != null and is_instance_valid(current_ui)) or ($PlayerUI/CollectionUI != null and $PlayerUI/CollectionUI.visible) or ($PlayerUI/TaskListUI != null and $PlayerUI/TaskListUI.visible) or ($PlayerUI/MilestoneListUI != null and $PlayerUI/MilestoneListUI.visible)
			if not is_ui_open:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("toggle_camera"):
		is_third_person = !is_third_person
		_apply_camera_mode()

	if event.is_action_pressed("jump") and not is_typing:
		jump_queued = true
	
	if event.is_action_pressed("toggle_tasks") and not is_typing:
		toggle_tasks()

	if event.is_action_pressed("toggle_milestones") and not is_typing:
		toggle_milestones()

	if event is InputEventKey and event.pressed and not is_typing:
		if event.keycode == KEY_1:
			switch_slot(0)
		elif event.keycode == KEY_2:
			switch_slot(1)
		elif event.keycode == KEY_3:
			switch_slot(2)
		elif event.keycode == KEY_T:
			switch_slot(3)

	if event.is_action_pressed("inventory"):
		toggle_collection()
	
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
				elif potential_target is Item and carried_item is Item and carried_item.data and carried_item.data.name == "detector_battery" and potential_target.data and potential_target.data.name == "detector_01":
					check_interaction()
				elif potential_target is Item and carried_item is Item and carried_item.data and carried_item.data.name == "detector_01" and potential_target.data and potential_target.data.name == "detector_battery":
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
				carried_items[current_slot_index] = null
				inventory_slots_updated.emit(carried_items, current_slot_index)
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

		elif target is Item and carried_item != null and carried_item is Item:
			if target.has_method("apply_item") and target.apply_item(carried_item):
				carried_item.destroy_item.rpc()
				carried_item = null
				carried_items[current_slot_index] = null
				inventory_slots_updated.emit(carried_items, current_slot_index)
			elif carried_item.has_method("apply_item") and carried_item.apply_item(target):
				target.destroy_item.rpc()

		# ... rest of your existing logic (Crates, etc.)
		elif target.is_in_group("interactables"):
			pick_up(target)


func pick_up(item):
	if not is_multiplayer_authority(): return

	$InteractAudioPlayer.stream = Global.interact_sound
	$InteractAudioPlayer.play()
	
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
		var is_tool = false
		if "data" in item and item.data != null and item.data.is_tool:
			is_tool = true

		if is_tool:
			if is_instance_valid(carried_items[3]):
				$PlayerUI/NotificationArea.display_message("You can't pick up another tool")

				# Give up authority, restore state
				item.sync_authority.rpc(1, false, Vector3.ZERO, item.global_position, item.global_rotation.y)
				return
			else:
				if carried_item == null:
					switch_slot(3)
				else:
					carried_items[3] = item
					var item_node = item
					item_node.visible = false
					if item_node.has_method("set_ghost_appearance"):
						item_node.set_ghost_appearance(false)

					var anchor = item_node.get_node_or_null("MeshAnchor")
					if anchor and anchor.get_child_count() > 0:
						var potential_tool = anchor.get_child(0)
						if potential_tool.has_method("update_proximity"):
							potential_tool.update_proximity(null)

					inventory_slots_updated.emit(carried_items, current_slot_index)
					placement_ray.add_exception(item)
					if "data" in item and item.data != null:
						emit_task_event("gather", item.data)
						var is_artifact = false
						if "item_value_type" in item.data:
							is_artifact = (item.data.item_value_type == ItemData.ItemValueType.ARTIFACT)
						if not is_artifact:
							var n = item.data.name
							if not items_held.has(n):
								items_held[n] = {"resource": item.data, "count": 1}
								collection_updated.emit({"items": items_held, "artifacts": artifacts_crafted})

					if "is_autospawned" in item:
						item.is_autospawned = false
					return
		else:
			if current_slot_index == 3:
				$PlayerUI/NotificationArea.display_message("You can't pick up a non-tool into the tool slot")
				item.sync_authority.rpc(1, false, Vector3.ZERO, item.global_position, item.global_rotation.y)
				return

		carried_item = item
		inventory_slots_updated.emit(carried_items, current_slot_index)
		placement_ray.add_exception(item)
		if "data" in item and item.data != null:
			emit_task_event("gather", item.data)

			var is_artifact = false
			if "item_value_type" in item.data:
				is_artifact = (item.data.item_value_type == ItemData.ItemValueType.ARTIFACT)

			if not is_artifact:
				var n = item.data.name
				if not items_held.has(n):
					items_held[n] = {"resource": item.data, "count": 1}
					collection_updated.emit({"items": items_held, "artifacts": artifacts_crafted})
		
		# If it's a naturally spawned item, mark it as claimed by a player so it gets saved
		if "is_autospawned" in carried_item:
			carried_item.is_autospawned = false

		if carried_item.has_method("set_ghost_appearance") and get_held_tool() == null:
			carried_item.set_ghost_appearance(true)
		
		# 1. ENABLE SYNC: Let the network sync the root transform.
		var sync = carried_item.get_node_or_null("MultiplayerSynchronizer")
		if sync:
			sync.set_process(true)
			sync.set_physics_process(true)
		
		# 3. PHYSICS & TOP LEVEL: 
		# Setting top_level = true means the item moves in Global Space, 
		# not "relative" to your hand.
		carried_item.freeze = true
		
		# 4. INITIAL SNAP: Put it at the proper marker immediately
		# is_tool is already declared at line 605
		if is_tool:
			carried_item.global_position = hand.global_position
			carried_item.global_basis = hand.global_basis.orthonormalized().scaled(carried_item.scale)
		else:
			carried_item.global_position = head_item_marker.global_position
			carried_item.global_basis = head_item_marker.global_basis.orthonormalized().scaled(carried_item.scale)

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
	carried_items[current_slot_index] = null
	inventory_slots_updated.emit(carried_items, current_slot_index)
	rotation_offset = 0.0
	
	var final_pos = item.global_position
	var final_rot = item.global_rotation.y
	
	var is_tool = false
	if "data" in item and item.data and "is_tool" in item.data and item.data.is_tool:
		is_tool = true

	var anchor = item.get_node_or_null("MeshAnchor")
	if anchor and not is_tool:
		if is_third_person:
			# In third person, it's just on the head. Let's drop it slightly in front.
			final_pos = global_position + (global_transform.basis.z * -1.0) + Vector3(0, 0.5, 0)
			final_rot = self.global_rotation.y
		else:
			# In first person, use the anchor's preview location, then reset the anchor
			final_pos = anchor.global_position
			final_rot = anchor.global_rotation.y
		var old_scale = anchor.scale
		anchor.transform = Transform3D.IDENTITY
		anchor.scale = old_scale

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
	carried_items[current_slot_index] = null
	inventory_slots_updated.emit(carried_items, current_slot_index)
	item.scale = Vector3.ONE

	# Reset the anchor offset so it doesn't throw from under the ground!
	var anchor = item.get_node_or_null("MeshAnchor")
	if anchor:
		var old_scale = anchor.scale
		anchor.transform = Transform3D.IDENTITY
		anchor.scale = old_scale
	
	# 1. CALCULATE DATA
	var launch_dir = Vector3.ZERO
	if is_third_person:
		# Use character body forward
		launch_dir = (-global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
		item.global_position = global_position + (launch_dir * 1.0) + Vector3(0, 1.0, 0)
	else:
		launch_dir = (-hand.global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
		item.global_position = hand.global_position + (launch_dir * 0.5)
		item.global_rotation = self.global_rotation

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

	# Only process proximity if we have a valid local player
	var my_id = multiplayer.get_unique_id()
	var local_player = get_node_or_null(Global.PLAYERS_CONTAINER_PATH + str(my_id))
	var distance = 0.0

	if local_player and is_instance_valid(local_player):
		distance = local_player.global_position.distance_to(global_position)

	# Log the message in the new ChatLog if within proximity, or if it's the local player
	if local_player == null or local_player == self or distance <= Global.chat_proximity_radius:
		var chat_log = get_node_or_null("/root/Main/CanvasLayer/ChatLog")
		if chat_log and chat_log.has_method("add_message"):
			chat_log.add_message(name, text, eye_color)
		
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
		
	# Process inactive carried items to keep them out of sight but attached to player position
	for i in range(carried_items.size()):
		if i != current_slot_index and is_instance_valid(carried_items[i]):
			var is_tool = false
			var inactive_item = carried_items[i]
			if "data" in inactive_item and inactive_item.data and "is_tool" in inactive_item.data and inactive_item.data.is_tool:
				is_tool = true
			if is_tool:
				inactive_item.global_position = hand.global_position
				inactive_item.global_basis = hand.global_basis.orthonormalized().scaled(inactive_item.scale)
			else:
				inactive_item.global_position = head_item_marker.global_position
				inactive_item.global_basis = head_item_marker.global_basis.orthonormalized().scaled(inactive_item.scale)
	
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
		carried_item.global_position = hand.global_position
		carried_item.global_basis = hand.global_basis.orthonormalized().scaled(carried_item.scale)
		return
	
	# For non-tools, the physical object stays on the head so other players see it there.
	carried_item.global_position = head_item_marker.global_position
	carried_item.global_basis = head_item_marker.global_basis.orthonormalized().scaled(carried_item.scale)

	var anchor = carried_item.get_node_or_null("MeshAnchor")

	if is_third_person:
		# We don't do raycast ghost in 3rd person for items, disable visual ghost mode
		if carried_item.has_method("set_ghost_appearance"):
			carried_item.set_ghost_appearance(false)
		carried_item.visible = true

		# Reset the anchor just in case it was offset in first person
		if anchor:
			var old_scale = anchor.scale
			anchor.transform = Transform3D.IDENTITY
			anchor.scale = old_scale

		can_place = true
		if carried_item.has_method("set_ghost_valid"):
			carried_item.set_ghost_valid(can_place)
		return

	if not anchor: return

	# 2. In First Person, the root physics object is locked to the player so other clients
	#    see it on the head. But LOCALLY we detach the visual MeshAnchor.
	#    Reset rotation completely so we evaluate purely from zero state
	var old_scale = anchor.scale
	anchor.transform = Transform3D.IDENTITY
	anchor.scale = old_scale
	# Apply standard preview rotation from the player
	anchor.global_rotation.y = self.global_rotation.y + rotation_offset

	var active_ray = placement_ray

		# 3. Calculate the Y-offset (distance to 'feet')
	var min_y = 0.0
	var found_collision = false

	# Helper to process a node's AABB in the item's local space
	var item_inv_trans = carried_item.global_transform.affine_inverse()

	# Find all CollisionShape3D nodes (recursive) under MeshAnchor
	var search_nodes = anchor.find_children("*", "CollisionShape3D", true, false)

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

	var y_offset = 0.0
	if found_collision:
		y_offset = -min_y

	# Apply scale just in case the parent is scaled
	y_offset *= carried_item.scale.y

	# Check if we are looking at a cart basket (via raycast OR interaction target)
	var looking_at_cart = false
	if active_ray.get_collider() and active_ray.get_collider().has_meta("is_cart_basket"):
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

		if active_ray.is_colliding():
			can_place = true

			# Validate surface angle
			var normal = active_ray.get_collision_normal()
			var floor_angle = normal.angle_to(Vector3.UP)
			if floor_angle > deg_to_rad(45.0):
				can_place = false

			# Move the visual anchor exactly to the floor point, plus the intrinsic bottom offset
			anchor.global_position = active_ray.get_collision_point() + Vector3(0, y_offset, 0)

			# Validate placement regarding tent state
			if get_tent_for_position(active_ray.get_collision_point()) != get_tent_for_position(global_position):
				can_place = false
		else:
			can_place = true
			# Fallback: tie it cleanly to the hands locally
			anchor.global_position = hand.global_position
			anchor.global_basis = hand.global_basis.orthonormalized().scaled(anchor.scale)

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

	var hint_text = ""

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
			elif potential_target is Item and carried_item is Item and carried_item.data and carried_item.data.name == "detector_battery" and potential_target.data and potential_target.data.name == "detector_01":
				var detector_skin = potential_target.get_node_or_null("MeshAnchor").get_child(0) if potential_target.has_node("MeshAnchor") and potential_target.get_node("MeshAnchor").get_child_count() > 0 else null
				if detector_skin and "charges" in detector_skin:
					target_text = "[E] charge detector +1 (" + str(detector_skin.charges) + "/" + str(detector_skin.max_charges) + " now)"
				else:
					target_text = "[E] charge detector"
				highlight_target = potential_target
			elif potential_target is Item and carried_item is Item and carried_item.data and carried_item.data.name == "detector_01" and potential_target.data and potential_target.data.name == "detector_battery":
				var detector_skin = carried_item.get_node_or_null("MeshAnchor").get_child(0) if carried_item.has_node("MeshAnchor") and carried_item.get_node("MeshAnchor").get_child_count() > 0 else null
				if detector_skin and "charges" in detector_skin:
					target_text = "[E] charge detector +1 (" + str(detector_skin.charges) + "/" + str(detector_skin.max_charges) + " now)"
				else:
					target_text = "[E] charge detector"
				highlight_target = potential_target
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

	if carried_item and carried_item is Item and carried_item.data and carried_item.data.name == "detector_01":
		var detector_skin = carried_item.get_node_or_null("MeshAnchor").get_child(0) if carried_item.has_node("MeshAnchor") and carried_item.get_node("MeshAnchor").get_child_count() > 0 else null
		if detector_skin and "charges" in detector_skin and detector_skin.charges <= 0:
			hint_text = "Needs batteries, buy them in shop"

	if target_text == "" or target_text == "You can't place it here":
		_update_highlight(null)
	else:
		_update_highlight(highlight_target)

	if hint_label:
		if hint_text != "":
			hint_label.text = hint_text
			hint_label.show()
		else:
			hint_label.hide()

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
	if current_furniture is RigidBody3D:
		current_furniture.freeze = true
	# Optional: Disable collision mask if needed so player doesn't pop out
	set_collision_mask_value(1, false)
	is_sitting = true
	_update_sit_visuals.rpc(true)

func leave_furniture():
	if not is_multiplayer_authority(): return
	if current_furniture != null:
		if current_furniture.has_method("leave"):
			current_furniture.leave(self)
		if current_furniture is RigidBody3D:
			current_furniture.freeze = false
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
		if state_swim: state_swim.hide()
	else:
		if state_sit: state_sit.hide()
		if state_stand: state_stand.show()
		if state_swim: state_swim.hide()

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



@rpc("any_peer", "call_local")
func add_to_collection_rpc(data_path: String):
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0: return
	if not is_multiplayer_authority(): return
	var data = load(data_path)
	if data:
		add_to_collection(data)

@rpc("any_peer", "call_local")
func add_to_artifacts_crafted_rpc(data_path: String):
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0: return
	if not is_multiplayer_authority(): return
	var data = load(data_path)
	if data:
		var n = data.name
		if artifacts_crafted.has(n):
			artifacts_crafted[n]["count"] += 1
		else:
			artifacts_crafted[n] = {"resource": data, "count": 1}
		collection_updated.emit({"items": items_held, "artifacts": artifacts_crafted})
func milestone_craft_rpc(data_path: String):
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0: return
	if not is_multiplayer_authority(): return
	var data = load(data_path)
	if data and data is ArtifactData:
		var milestones_ui = $PlayerUI/MilestoneListUI
		if milestones_ui and milestones_ui.has_method("handle_milestone_event"):
			milestones_ui.handle_milestone_event("craft", null, data)

func add_to_collection(data: ItemData):
	var n = data.name
	if collection.has(n):
		collection[n]["count"] += 1
	else:
		collection[n] = {"resource": data, "count": 1}
	
	collection_updated.emit(collection)
	
	if is_multiplayer_authority():
		$PlayerUI/NotificationArea.display_message("Found: " + data.display_name + "!")

		pass


func toggle_milestones():
	if not is_multiplayer_authority(): return

	var milestones_ui = $PlayerUI/MilestoneListUI
	if not milestones_ui: return

	milestones_ui.visible = !milestones_ui.visible

	if milestones_ui.visible:
		var inv_ui = $PlayerUI/InventoryUI
		if inv_ui: inv_ui.visible = false
		var tasks_ui = $PlayerUI/TaskListUI
		if tasks_ui: tasks_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_tasks():
	if not is_multiplayer_authority(): return

	var tasks_ui = $PlayerUI/TaskListUI
	if not tasks_ui: return

	tasks_ui.visible = !tasks_ui.visible

	if tasks_ui.visible:
		var inv_ui = $PlayerUI/CollectionUI
		if inv_ui: inv_ui.visible = false
		var milestones_ui = $PlayerUI/MilestoneListUI
		if milestones_ui: milestones_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_collection():
	if not is_multiplayer_authority(): return
	
	var inv_ui = $PlayerUI/CollectionUI
	inv_ui.visible = !inv_ui.visible
	
	if inv_ui.visible:
		var tasks_ui = $PlayerUI/TaskListUI
		if tasks_ui: tasks_ui.visible = false
		var milestones_ui = $PlayerUI/MilestoneListUI
		if milestones_ui: milestones_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# FORCE A REFRESH SO IT'S NOT EMPTY
		inv_ui.refresh_ui({"items": items_held, "artifacts": artifacts_crafted})
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


@rpc("any_peer", "call_local")
func emit_task_event(action: String, item_data_or_path):
	if not is_multiplayer_authority(): return
	var item_data: ItemData
	if typeof(item_data_or_path) == TYPE_STRING:
		item_data = load(item_data_or_path) as ItemData
	else:
		item_data = item_data_or_path

	if item_data != null:
		var tasks_ui = $PlayerUI/TaskListUI
		if tasks_ui and tasks_ui.has_method("handle_task_event"):
			tasks_ui.handle_task_event(action, item_data)

		var milestones_ui = $PlayerUI/MilestoneListUI
		if milestones_ui and milestones_ui.has_method("handle_milestone_event"):
			milestones_ui.handle_milestone_event(action, item_data)

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
const OUTLINE_MATERIAL = preload(Global.HIGHLIGHT_OBJECT_MAT_PATH)

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
	_highlight_camera.environment.background_color = Color(0, 0, 0, 0)

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

		# Performance Optimization: Cache meshes on the target node to avoid O(N) recursive crawls
		if _highlighted_node.has_meta("_cached_meshes"):
			var cached = _highlighted_node.get_meta("_cached_meshes")
			var valid_cache = true
			# Validate cached meshes (in case any were freed or the tree changed)
			for m in cached:
				if is_instance_valid(m):
					_highlight_meshes.append(m)
				else:
					# If any are invalid, the cache is stale; clear and re-crawl
					valid_cache = false
					break

			if not valid_cache:
				_highlight_meshes.clear()
				_get_meshes_recursive(_highlighted_node, _highlight_meshes)
				_highlighted_node.set_meta("_cached_meshes", _highlight_meshes.duplicate())
		else:
			_get_meshes_recursive(_highlighted_node, _highlight_meshes)
			_highlighted_node.set_meta("_cached_meshes", _highlight_meshes.duplicate())

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
		_highlight_tween.tween_callback(_on_highlight_fade_out_complete)

func _on_highlight_fade_out_complete() -> void:
	for m in _highlight_meshes:
		if is_instance_valid(m):
			m.layers &= ~HIGHLIGHT_LAYER
	_highlight_meshes.clear()


func _play_footstep_sound():
	
	if not $WalkAudioPlayer.playing:
		
		if (footstep_iterator%2==0):
			$WalkAudioPlayer.stream = Global.sand_walk_sound
			$WalkAudioPlayer.volume_db = Global.walk_sound_1_volume
		else:
			$WalkAudioPlayer.stream = Global.sand_walk_sound_2
			$WalkAudioPlayer.volume_db = Global.walk_sound_2_volume
		$WalkAudioPlayer.play()
		footstep_iterator += 1
