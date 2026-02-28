extends Tool

var blink_light: OmniLight3D
var audio_player: AudioStreamPlayer3D

func _ready():
	# Search the entire shovel scene for the required components
	blink_light = find_child("IndicatorLight", true, false) as OmniLight3D
	audio_player = _find_by_type(self, "AudioStreamPlayer3D")
	
	if not blink_light:
		blink_light = _find_by_type(self, "OmniLight3D")

	if blink_light and audio_player:
		print("Detector: Light and Sound found via Type Scan.")
		blink_light.visible = false
	else:
		# This will help us see exactly what IS inside the scene
		print("--- DEBUG: Shovel Hierarchy Check ---")
		_print_hierarchy(self, "")
		printerr("Detector Error: Still missing components!")

# Helper: Finds a node by its Class Name
func _find_by_type(root, type_name):
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found = _find_by_type(child, type_name)
		if found: return found
	return null
	


# Helper: Prints everything so we can see why paths fail
func _print_hierarchy(node, indent):
	print(indent, node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		_print_hierarchy(child, indent + "  ")

var timer = 0.0

var active_treasure = null 

var near_blip = 0.25
var far_blip = 2.0

var near_pitch = 1.4
var far_pitch = 0.3


func get_action_name() -> String:
	return "Detect"



func _process(delta):
	# If we are not in the tree or networking isn't ready, skip
	if not is_inside_tree(): return
	
	# WARNING: If this is a child of the BaseItem, 
	# make sure the BaseItem gave authority to the player!
	# If you want it to beep for everyone, remove the authority check.
	if not is_multiplayer_authority(): return
	
	if not active_treasure or not is_instance_valid(active_treasure):
		active_treasure = null
		return
		
	var distance = global_position.distance_to(active_treasure.global_position)
	
	print("I HAVE A TREASURE! Distance: ", distance)
	
	# Detection Logic
	if active_treasure.has_method("reveal_location"):
		if distance < 3.0:
			active_treasure.reveal_location(distance)
		else:
			active_treasure.hide_location()
	
	# Timing Logic
	var beep_interval = remap(clamp(distance, 0, 15.0), 0, 15.0, near_blip, far_blip)
	
	timer += delta
	if timer >= beep_interval:
		play_beep(distance)
		timer = 0.0

# ------------------------------
func update_proximity(treasure):
	if treasure:
		print("--- [DETECTOR LOGIC] ---")
		print("    Target Received: ", treasure.name)
		print("    Target Groups: ", treasure.get_groups())
		
	active_treasure = treasure
	if treasure == null:
		timer = 0.0
		

func play_beep(dist):
	if audio_player:
		audio_player.pitch_scale = remap(clamp(dist, 0, 15.0), 0, 15.0, near_pitch, far_pitch)
		audio_player.play()
		
	show_blink_fx.rpc()


@rpc("any_peer", "call_local")
func show_blink_fx():
	if not blink_light: return
	
	# Stop any existing tween so they don't overlap and look messy
	var tween = create_tween()
	
	blink_light.visible = true
	# Instant flash
	blink_light.light_energy = 3.0 
	
	# Fade out - the duration (0.15) should be short 
	# so it doesn't stay lit when beeping fast
	tween.tween_property(blink_light, "light_energy", 0.0, 0.1)
