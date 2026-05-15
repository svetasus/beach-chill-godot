extends CPUParticles3D

func _ready():
	emitting = true
	# Wait for the particles to finish, then delete the node
	var total_time = lifetime + 0.5 
	get_tree().create_timer(total_time).timeout.connect(func(): queue_free())
	#queue_free()
