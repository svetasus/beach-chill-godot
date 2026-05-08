extends StaticBody3D

@export var recipes: Array[ArtifactData] = []
@export var paper_scene: PackedScene = preload("res://scenes/features/combiner/artifactPaper.tscn")
@export var paper_scale: Vector3 = Vector3(2.2, 2.2, 2.2)

var paper_positions: Array[Vector3] = [
	Vector3(-0.339, 0.211, 0),
	Vector3(-0.339, -0.162, 0),
	Vector3(0.288, 0.211, 0),
	Vector3(0.288, -0.162, 0)
]

var items_in_zone: Array[Node3D] = []

@onready var artifact_slots = $ArtifactSlots

func _ready():
	if multiplayer.is_server():
		# Assuming blueprintBoard and ArtifactCombiner are siblings inside CombinerFull
		var detection_area = get_parent().get_node_or_null("ArtifactCombiner/DetectionArea")
		if detection_area:
			detection_area.body_entered.connect(_on_detection_area_body_entered)
			detection_area.body_exited.connect(_on_detection_area_body_exited)

func _on_detection_area_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if body.is_in_group("interactables") and not items_in_zone.has(body):
		items_in_zone.append(body)
		check_and_update_board()

func _on_detection_area_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if items_in_zone.has(body):
		items_in_zone.erase(body)
		check_and_update_board()

func check_and_update_board():
	if not multiplayer.is_server(): return

	items_in_zone = items_in_zone.filter(func(item): return is_instance_valid(item))

	var current_parts_data = []
	for item in items_in_zone:
		var d = item.get("data")
		if d != null:
			current_parts_data.append(d)

	if current_parts_data.is_empty():
		rpc("update_board_rpc", [])
		return

	var matched_recipes_paths = []

	for recipe in recipes:
		if recipe == null: continue
		var contains_all = true
		for part_data in current_parts_data:
			if not recipe.required_parts.has(part_data):
				contains_all = false
				break
		if contains_all:
			matched_recipes_paths.append(recipe.resource_path)
			if matched_recipes_paths.size() >= 4:
				break

	rpc("update_board_rpc", matched_recipes_paths)

@rpc("call_local", "reliable")
func update_board_rpc(matched_recipe_paths: Array):
	# Clear existing papers
	for child in artifact_slots.get_children():
		child.queue_free()

	# Wait for queue_free
	if not matched_recipe_paths.is_empty():
		# instantiate papers for up to 4 recipes
		for i in range(min(matched_recipe_paths.size(), 4)):
			var path = matched_recipe_paths[i]
			var recipe = load(path) as ArtifactData
			if not recipe: continue

			var paper = paper_scene.instantiate()
			artifact_slots.add_child(paper)

			paper.transform.origin = paper_positions[i]
			paper.scale = paper_scale

			# Setup textures
			var sprite_final = paper.get_node("SpriteFinalArtifact")
			var sprite_frag1 = paper.get_node("Fragments/SpriteFragment1")
			var sprite_frag2 = paper.get_node("Fragments/SpriteFragment2")
			var sprite_frag3 = paper.get_node("Fragments/SpriteFragment3")

			var sprite_note1 = paper.get_node("Notes/SpriteNote1")
			var sprite_note2 = paper.get_node("Notes/SpriteNote2")
			var sprite_note3 = paper.get_node("Notes/SpriteNote3")

			if recipe.result_item and recipe.result_item.item_icon:
				sprite_final.texture = recipe.result_item.item_icon

			if recipe.required_parts.size() > 0 and recipe.required_parts[0] and recipe.required_parts[0].item_icon:
				sprite_frag1.texture = recipe.required_parts[0].item_icon
			if recipe.required_parts.size() > 1 and recipe.required_parts[1] and recipe.required_parts[1].item_icon:
				sprite_frag2.texture = recipe.required_parts[1].item_icon
			if recipe.required_parts.size() > 2 and recipe.required_parts[2] and recipe.required_parts[2].item_icon:
				sprite_frag3.texture = recipe.required_parts[2].item_icon

			if recipe.required_parts.size() == 2:
				sprite_note2.visible = false
				sprite_frag3.visible = false

				sprite_frag1.global_position = sprite_note1.global_position
				sprite_frag2.global_position = sprite_note2.global_position

				sprite_note1.transform.origin.x = 0
