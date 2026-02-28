extends Tool

var initial_rotation: Vector3 # Store the mesh's starting pose
#@onready var pivot = get_parent().get_node("Model")
@onready var pivot = $Model


func _ready():
	await get_tree().process_frame
	if pivot:
		initial_rotation = pivot.rotation

func get_action_name() -> String:
	return "Dig"

func can_interact_with(target) -> bool:
	if target == null or not target.is_in_group("treasures"):
		return false
	
	var item_root = get_parent()
	
	# Check if the player holding this shovel is close enough to dig
	# We search for the player by checking who has authority over this item
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.get_multiplayer_authority() == item_root.get_multiplayer_authority():
			# 'can_dig' is a variable in your player.gd
			return player.can_dig
		
	return false

func use_tool(target):
	if target.has_method("dig_up"):
		# We pass 'true' to indicate a successful dig
		play_dig_animation()
		target.dig_up()


func play_dig_animation():
	var tween = create_tween()

	# Using 'set_trans' makes the movement feel more like a physical impact
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 1. Tilt Forward (Stab)
	tween.tween_property(pivot, "rotation:x", initial_rotation.x + deg_to_rad(-45), 0.1)
	
	# 2. Scoop Backward (Lifting the sand)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pivot, "rotation:x", initial_rotation.x + deg_to_rad(20), 0.2)
	
	# 3. Return to rest
	tween.tween_property(pivot, "rotation:x", initial_rotation.x, 0.1)
	
