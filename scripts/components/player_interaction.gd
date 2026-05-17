extends Node
class_name PlayerInteraction

var player: CharacterBody3D

const HIGHLIGHT_LAYER = 1 << 19
var _highlight_camera: Camera3D
var _highlight_container: SubViewportContainer
var _highlight_viewport: SubViewport
var _highlighted_node = null
var _highlight_meshes: Array[MeshInstance3D] = []
var _highlight_tween: Tween
var OUTLINE_MATERIAL = preload(Global.HIGHLIGHT_OBJECT_MAT_PATH)

func _ready():
	player = get_parent()

func get_interaction_target():
	var active_shapecast = player.get_node("Body/Head/Camera3D/InteractionShape")
	if player.is_third_person:
		active_shapecast = player.tp_shapecast

	if active_shapecast.is_colliding():
		var collision_count = active_shapecast.get_collision_count()

		var my_tent = player.get_tent_for_position(player.global_position)

		if player.get_node("PlayerInventory").get_carried_item() == null:
			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if collider is Item:
					if player.get_tent_for_position(collider.global_position) == my_tent:
						return collider

			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if player.get_tent_for_position(collider.global_position) != my_tent: continue

				if collider.has_method("deposit_item") or collider.has_method("get_interaction_text") or collider.has_method("interact"):
					return collider
				if collider.has_meta("is_cart_handle") or collider.has_meta("is_cart_basket"):
					return collider
		else:
			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if player.get_tent_for_position(collider.global_position) != my_tent: continue

				if collider.has_method("deposit_item") or collider.has_meta("is_cart_basket"):
					return collider

			for i in range(collision_count):
				var collider = active_shapecast.get_collider(i)
				if player.get_tent_for_position(collider.global_position) != my_tent: continue

				if collider is Item or collider.has_method("interact") or collider.has_meta("is_cart_handle"):
					return collider

	return null

func check_interaction():
	if not player.can_interact_here(): return
	if not player.is_multiplayer_authority(): return

	var target = get_interaction_target()
	if target:
		if target.has_method("deposit_item"):
			if player.get_node("PlayerInventory").get_carried_item() != null:
				player._rpc_request_deposit.rpc_id(1, target.get_path(), player.get_node("PlayerInventory").get_carried_item().get_path())
				player.get_node("PlayerInventory").set_carried_item(null)
				player.get_node("PlayerInventory").carried_items[player.get_node("PlayerInventory").current_slot_index] = null
				player.get_node("PlayerInventory").inventory_slots_updated.emit(player.get_node("PlayerInventory").carried_items, player.get_node("PlayerInventory").current_slot_index)
			else:
				if target.has_method("interact"):
					target.interact(player)

		elif target.has_method("interact"):
			target.interact(player)

		elif target.has_meta("is_cart_handle"):
			if player.get_node("PlayerInventory").get_carried_item() == null:
				var cart_node = target.get_meta("cart_node")
				player._rpc_toggle_cart_grab.rpc_id(1, cart_node.get_path())
		elif target.has_meta("is_cart_basket"):
			if player.get_node("PlayerInventory").get_carried_item() != null:
				var cart_node = target.get_meta("cart_node")
				player.can_place = true
				player._rpc_request_cart_deposit.rpc_id(1, cart_node.get_path(), player.get_node("PlayerInventory").get_carried_item().get_path())
				player.drop_item()

		elif target is Item and target.freeze == true:
			print("Someone is already holding this!")
			return

		elif target is Item and player.get_node("PlayerInventory").get_carried_item() != null and player.get_node("PlayerInventory").get_carried_item() is Item:
			if target.has_method("apply_item") and target.apply_item(player.get_node("PlayerInventory").get_carried_item()):
				player.get_node("PlayerInventory").get_carried_item().destroy_item.rpc()
				player.get_node("PlayerInventory").set_carried_item(null)
				player.get_node("PlayerInventory").carried_items[player.get_node("PlayerInventory").current_slot_index] = null
				player.get_node("PlayerInventory").inventory_slots_updated.emit(player.get_node("PlayerInventory").carried_items, player.get_node("PlayerInventory").current_slot_index)
			elif player.get_node("PlayerInventory").get_carried_item().has_method("apply_item") and player.get_node("PlayerInventory").get_carried_item().apply_item(target):
				target.destroy_item.rpc()

		elif target.is_in_group("interactables"):
			player.pick_up(target)


func _ready_highlight_system():
	_highlight_container = SubViewportContainer.new()
	_highlight_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_container.stretch = true

	_highlight_container.material = OUTLINE_MATERIAL.duplicate()

	_highlight_viewport = SubViewport.new()
	_highlight_viewport.transparent_bg = true
	_highlight_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_highlight_camera = Camera3D.new()
	_highlight_camera.cull_mask = HIGHLIGHT_LAYER
	_highlight_camera.environment = Environment.new()
	_highlight_camera.environment.background_mode = Environment.BG_COLOR
	_highlight_camera.environment.background_color = Color(0, 0, 0, 0)

	_highlight_viewport.add_child(_highlight_camera)
	_highlight_container.add_child(_highlight_viewport)

	if player.has_node("PlayerUI"):
		player.get_node("PlayerUI").add_child(_highlight_container)
		player.get_node("PlayerUI").move_child(_highlight_container, 0)

func _sync_highlight_camera():
	if not _highlight_camera: return

	var main_cam = player.get_node("Body/Head/Camera3D")
	if player.is_third_person:
		main_cam = player.tp_camera

	if main_cam and main_cam.current:
		_highlight_camera.global_transform = main_cam.global_transform
		_highlight_camera.fov = main_cam.fov
		_highlight_camera.size = main_cam.size

func _get_meshes_recursive(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_get_meshes_recursive(child, meshes)

func _update_highlight(target_node: Node) -> void:
	if _highlighted_node == target_node:
		return

	if _highlighted_node != null and is_instance_valid(_highlighted_node):
		_fade_highlight(false)

	_highlighted_node = target_node

	if _highlighted_node != null and is_instance_valid(_highlighted_node):
		if _highlight_meshes.size() > 0:
			for m in _highlight_meshes:
				if is_instance_valid(m):
					m.layers &= ~HIGHLIGHT_LAYER
		_highlight_meshes.clear()

		if _highlighted_node.has_meta("_cached_meshes"):
			var cached = _highlighted_node.get_meta("_cached_meshes")
			var valid_cache = true
			for m in cached:
				if is_instance_valid(m):
					_highlight_meshes.append(m)
				else:
					valid_cache = false
					break

			if not valid_cache:
				_highlight_meshes.clear()
				_get_meshes_recursive(_highlighted_node, _highlight_meshes)
				_highlighted_node.set_meta("_cached_meshes", _highlight_meshes.duplicate())
		else:
			_get_meshes_recursive(_highlighted_node, _highlight_meshes)
			_highlighted_node.set_meta("_cached_meshes", _highlight_meshes.duplicate())

		for m in _highlight_meshes:
			if is_instance_valid(m):
				m.layers |= HIGHLIGHT_LAYER

		_fade_highlight(true)

func _fade_highlight(fade_in: bool) -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()

	_highlight_tween = player.create_tween()
	var mat = _highlight_container.material

	if fade_in:
		_highlight_tween.tween_property(mat, "shader_parameter/alpha_multiplier", 1.0, 0.2)
	else:
		_highlight_tween.tween_property(mat, "shader_parameter/alpha_multiplier", 0.0, 0.2)
		_highlight_tween.tween_callback(self._on_highlight_fade_out_complete)

func _on_highlight_fade_out_complete() -> void:
	for m in _highlight_meshes:
		if is_instance_valid(m):
			m.layers &= ~HIGHLIGHT_LAYER
	_highlight_meshes.clear()
