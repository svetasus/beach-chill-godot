extends SceneTree

func _init():
	var item_data = RecipeData.new()
	item_data.name = "recipe_scroll_artifact_001"
	item_data.display_name = "Recipe Scroll: Bear Statue"
	item_data.is_collectible = true
	item_data.is_furniture = false
	item_data.scene = load("res://scenes/items/recipe_scroll_visuals.tscn")
	item_data.target_recipe = load("res://resources/combiner_recipes/artifact_001_recipe.tres")
	ResourceSaver.save(item_data, "res://resources/items/recipe_scroll_artifact_001.tres")

	quit(0)
