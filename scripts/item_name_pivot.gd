extends Node3D
func _process(_delta):
	# This keeps the pivot's rotation globally fixed to "up"
	# even if the parent (the ingredient) is tumbling.
	global_rotation = Vector3.ZERO
