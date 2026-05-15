extends SceneTree

func _init():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.6) # beige

	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = 0.3
	mesh.material = mat

	ResourceSaver.save(mesh, "res://resources/items/scroll_mesh.tres")

	quit(0)
