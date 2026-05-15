extends Node3D
class_name Tool

# Called when we are near a treasure (for the detector)
func update_proximity(treasure):
	pass

# Called when the player presses 'Interact' while looking at something
func can_interact_with(target) -> bool:
	return false

# The actual action (Digging, Fishing, etc.)
func use_tool(target):
	pass
