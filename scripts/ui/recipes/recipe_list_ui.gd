extends Control

@export var recipe_prefab: PackedScene

@onready var recipes_container = $PanelContainer/VBoxContainer/ScrollContainer/RecipesContainer

var local_player: Node = null

func _ready():
	hide()

func get_local_player() -> Node:
	if local_player and is_instance_valid(local_player):
		return local_player
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.is_multiplayer_authority():
			local_player = p
			return local_player
	return null

func refresh_ui():
	var player = get_local_player()
	if not player: return

	# Clean up old elements
	for child in recipes_container.get_children():
		child.queue_free()

	var recipe_list_res = load("res://resources/combiner_recipes/artifact_recipes_list.tres") as ArtifactRecipeList
	if not recipe_list_res: return

	var unlocked_recipes = player.get("recipes_unlocked")
	if typeof(unlocked_recipes) != TYPE_ARRAY:
		unlocked_recipes = []

	var crafted_artifacts = player.get("artifacts_crafted")
	if typeof(crafted_artifacts) != TYPE_DICTIONARY:
		crafted_artifacts = {}

	for recipe in recipe_list_res.recipes:
		if not recipe: continue

		var is_unlocked = unlocked_recipes.has(recipe.resource_path)
		var is_crafted = false
		if recipe.result_item and crafted_artifacts.has(recipe.result_item.name):
			is_crafted = true

		var items_held = player.get("items_held")
		if typeof(items_held) != TYPE_DICTIONARY:
			items_held = {}

		var ui_elem = recipe_prefab.instantiate()
		recipes_container.add_child(ui_elem)
		ui_elem.setup(recipe, is_unlocked, is_crafted, items_held)
