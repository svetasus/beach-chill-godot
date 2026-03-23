extends Area3D
class_name WaterArea

func _ready():
	# Configure collision settings:
	# layer 4 (bit 3) and mask 2 (bit 1 for player layer)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(4, true)
	set_collision_mask_value(2, true)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_water_surface_height() -> float:
	var max_y = global_position.y
	# Search for all collision shapes to find the highest point
	for child in get_children():
		if child is CollisionShape3D and child.shape != null:
			var shape = child.shape
			var shape_pos_y = child.global_position.y
			var half_height = 0.0

			if shape is BoxShape3D:
				half_height = shape.size.y / 2.0
			elif shape is CylinderShape3D:
				half_height = shape.height / 2.0
			elif shape is CapsuleShape3D:
				half_height = shape.height / 2.0
			elif shape is SphereShape3D:
				half_height = shape.radius

			var top_y = shape_pos_y + half_height
			if top_y > max_y:
				max_y = top_y

	return max_y

func _on_body_entered(body: Node3D):
	if body.has_method("enter_water"):
		body.enter_water(get_water_surface_height())

func _on_body_exited(body: Node3D):
	if body.has_method("exit_water"):
		body.exit_water()
