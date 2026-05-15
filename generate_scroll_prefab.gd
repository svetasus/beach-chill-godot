extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "RecipeScrollVisuals"

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = load("res://resources/items/scroll_mesh.tres")
	root.add_child(mesh_inst)
	mesh_inst.owner = root

	# Add the script
	var script = load("res://scripts/recipe_logic.gd")
	root.set_script(script)

	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/items/recipe_scroll_visuals.tscn")

	quit(0)
