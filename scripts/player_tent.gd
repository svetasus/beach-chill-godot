extends Node3D

@export var owner_id: int = -1 # The multiplayer ID of the player

func _ready():
	# Visual cue: Maybe change a flag or light color to match the player?
	pass

# This is the "Bouncer" function
func can_player_modify(player_id: int) -> bool:
	return player_id == owner_id

func set_tent_owner(new_id: int):
	owner_id = new_id
	print("Tent initialized for Player: ", owner_id)
	
	# Optional: Update a label or light color here
	if has_node("NameLabel"):
		$NameLabel.text = "Player " + str(owner_id) + "'s Tent"
