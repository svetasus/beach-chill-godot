extends CPUParticles3D

func _ready():
	# This ensures the particles start from frame 1 the moment they enter the world
	restart() 
	emitting = true
	
	# Auto-delete logic
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
