extends Node

var player

const SPEED = 5.0
var RUN_SPEED: float = 8.0
const JUMP_VELOCITY = 4.5
var SWIM_SPEED: float = 3.0
var WATER_JUMP_VELOCITY: float = 5.0
var WATER_FLOAT_OFFSET: float = -0.3

var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.3

var water_areas_count: int = 0
var current_water_surface_height: float = 0.0

var jump_queued = false

func _ready() -> void:
	player = get_parent()
	RUN_SPEED = player.RUN_SPEED
	SWIM_SPEED = player.SWIM_SPEED
	WATER_JUMP_VELOCITY = player.WATER_JUMP_VELOCITY
	WATER_FLOAT_OFFSET = player.WATER_FLOAT_OFFSET

func enter_water(surface_height: float):
	water_areas_count += 1
	current_water_surface_height = max(current_water_surface_height, surface_height)

func exit_water():
	water_areas_count -= 1
	if water_areas_count <= 0:
		water_areas_count = 0
		current_water_surface_height = 0.0

func process_movement(delta: float) -> void:
	if not player.is_multiplayer_authority() or player.is_typing: return

	if player.tp_spring_arm.top_level:
		player.tp_spring_arm.global_position = player.global_position + Vector3(0, 1.0, 0)

	if player.get('current_furniture') != null and is_instance_valid(player.get('current_furniture')):
		player.global_position = player.get('current_furniture').global_position + Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		player.move_and_slide()
		return

	var float_line = current_water_surface_height + WATER_FLOAT_OFFSET
	var is_swimming = water_areas_count > 0 and player.global_position.y <= float_line and not player.is_on_floor()

	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	if is_swimming:
		var depth = float_line - player.global_position.y
		var buoyancy_acceleration = depth * 20.0
		var water_drag = 2.0
		player.velocity.y += buoyancy_acceleration * delta
		player.velocity.y -= player.velocity.y * water_drag * delta

	if jump_queued:
		jump_queued = false
		if player.is_on_floor():
			player.velocity.y = JUMP_VELOCITY
		elif is_swimming:
			player.velocity.y = WATER_JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var direction := Vector3.ZERO
	if player.is_third_person:
		var cam_basis = player.tp_spring_arm.global_transform.basis
		direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction.y = 0
		direction = direction.normalized()

		if direction != Vector3.ZERO:
			var target_rot = atan2(-direction.x, -direction.z)
			player.rotation.y = lerp_angle(player.rotation.y, target_rot, 10.0 * delta)
	else:
		direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var was_running = player.is_running
	player.is_running = not is_swimming and player.is_on_floor() and direction != Vector3.ZERO and Input.is_action_pressed("run")
	if player.is_running != was_running:
		player._update_run_visuals.rpc(player.is_running)
	var current_speed = SWIM_SPEED if is_swimming else (RUN_SPEED if player.is_running else SPEED)

	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)

	if player.is_on_floor() and direction != Vector3.ZERO:
		footstep_timer += delta
		if footstep_timer >= FOOTSTEP_INTERVAL / (current_speed / SPEED):
			if player.has_method("_play_footstep_sound"):
				player._play_footstep_sound()
			footstep_timer = 0.0
	else:
		footstep_timer = 0.0

	player.move_and_slide()

	if direction != Vector3.ZERO and player.is_on_floor():
		var space_state = player.get_world_3d().direct_space_state
		var forward_offset = direction * 0.5
		var ray_origin = player.global_position + forward_offset + Vector3(0, 0.4, 0)
		var ray_end = ray_origin + Vector3(0, -0.5, 0)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [player.get_rid()]
		query.collision_mask = 1

		var result = space_state.intersect_ray(query)
		if result:
			var step_height = result.position.y - player.global_position.y
			if step_height > 0.05 and step_height <= 0.4:
				player.global_position.y = lerp(player.global_position.y, result.position.y, 15.0 * delta)
