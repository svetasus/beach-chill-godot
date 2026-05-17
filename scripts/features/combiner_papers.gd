extends StaticBody3D

@export var recipe_list: ArtifactRecipeList
@export var paper_scene: PackedScene = preload("res://scenes/features/combiner/artifactPaper.tscn")
@export var paper_scale: Vector3 = Vector3(2.2, 2.2, 2.2)

var paper_positions: Array[Vector3] = [
	Vector3(-0.339, 0.211, 0),
	Vector3(-0.339, -0.162, 0),
	Vector3(0.288, 0.211, 0),
	Vector3(0.288, -0.162, 0)
]

@onready var artifact_slots = $ArtifactSlots
var combiner_node: Node3D = null

func _ready():
	if multiplayer.is_server():
		# Assuming blueprintBoard and ArtifactCombiner are siblings inside CombinerFull
		combiner_node = get_parent().get_node_or_null("ArtifactCombiner")
		if combiner_node:
			combiner_node.items_changed.connect(check_and_update_board)

func check_and_update_board():
	if not multiplayer.is_server(): return
	if recipe_list == null: return

	if not combiner_node: return

	var items_in_zone = combiner_node.items_in_zone

	var current_parts_data = []
	for item in items_in_zone:
		if is_instance_valid(item):
			var d = item.get("data")
			if d != null:
				current_parts_data.append(d)

	if current_parts_data.is_empty():
		rpc("update_board_rpc", [])
		return

	var matched_recipes_paths = []

	for recipe in recipe_list.recipes:
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
			var sprite_outline = paper.get_node("SpriteOutline")
			var sprite_final_notes = paper.get_node("SpriteFinalNotes")

			var layout_2 = paper.get_node_or_null("Layout2Parts")
			var layout_3 = paper.get_node_or_null("Layout3Parts")

			if layout_2: layout_2.visible = false
			if layout_3: layout_3.visible = false

			if recipe.result_item and recipe.result_item.item_icon:
				sprite_final.texture = recipe.result_item.item_icon
				sprite_outline.texture = recipe.result_item.item_icon

			var local_player = null
			for p in get_tree().get_nodes_in_group("players"):
				if p.is_multiplayer_authority():
					local_player = p
					break # Needs to be the local client player

			var is_unlocked = false
			if local_player and "recipes_unlocked" in local_player:
				is_unlocked = local_player.recipes_unlocked.has(recipe.resource_path)

			var has_crafted = false
			if local_player and "artifacts_crafted" in local_player:
				if local_player.artifacts_crafted.has(recipe.result_item.name):
					has_crafted = true

			# If the recipe is not unlocked, show just the silhouette
			if not is_unlocked:
				sprite_final.visible = false
				sprite_final_notes.visible = false
				sprite_outline.visible = true
				sprite_outline.modulate = Color(0, 0, 0, 0.77) # completely dark outline
				if layout_2: layout_2.visible = false
				if layout_3: layout_3.visible = false
			else:
				# It is unlocked, check if it was crafted or not
				if has_crafted:
					sprite_final.visible = true
					sprite_final_notes.visible = true
					sprite_outline.visible = false
				else:
					sprite_final.visible = false
					sprite_final_notes.visible = false
					sprite_outline.visible = true

				# Determine which layout to show based on parts size
				var active_layout = null
				if recipe.required_parts.size() == 2 and layout_2:
					layout_2.visible = true
					active_layout = layout_2
				elif recipe.required_parts.size() >= 3 and layout_3:
					layout_3.visible = true
					active_layout = layout_3
				elif layout_3:
					# fallback to 3 parts if missing layout_2
					layout_3.visible = true
					active_layout = layout_3

				if active_layout:
					var sprite_frag1 = active_layout.get_node_or_null("Fragments/SpriteFragment1")
					var sprite_frag2 = active_layout.get_node_or_null("Fragments/SpriteFragment2")
					var sprite_frag3 = active_layout.get_node_or_null("Fragments/SpriteFragment3")

					var items_held = {}
					if local_player and "items_held" in local_player:
						items_held = local_player.items_held

					if sprite_frag1 and recipe.required_parts.size() > 0 and recipe.required_parts[0] and recipe.required_parts[0].item_icon:
						sprite_frag1.texture = recipe.required_parts[0].item_icon
						if not items_held.has(recipe.required_parts[0].name):
							sprite_frag1.modulate = Color(0, 0, 0, 0.776)
						else:
							sprite_frag1.modulate = Color(1, 1, 1, 1)
					if sprite_frag2 and recipe.required_parts.size() > 1 and recipe.required_parts[1] and recipe.required_parts[1].item_icon:
						sprite_frag2.texture = recipe.required_parts[1].item_icon
						if not items_held.has(recipe.required_parts[1].name):
							sprite_frag2.modulate = Color(0, 0, 0, 0.776)
						else:
							sprite_frag2.modulate = Color(1, 1, 1, 1)
					if sprite_frag3 and recipe.required_parts.size() > 2 and recipe.required_parts[2] and recipe.required_parts[2].item_icon:
						sprite_frag3.texture = recipe.required_parts[2].item_icon
						if not items_held.has(recipe.required_parts[2].name):
							sprite_frag3.modulate = Color(0, 0, 0, 0.776)
						else:
							sprite_frag3.modulate = Color(1, 1, 1, 1)
