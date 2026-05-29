extends Control

@export var milestone_prefab: PackedScene
@export var all_milestones: Array[MilestoneData] = []

var milestone_states: Dictionary = {} # milestone_id -> MilestoneState
var milestone_elements: Dictionary = {} # milestone_id -> MilestoneUIElement

@onready var grid_container = $PanelContainer/ScrollContainer/GridContainer

const GRID_SPACING_X = 400
const GRID_SPACING_Y = 150
const LINE_COLOR = Color(0.2, 0.2, 0.2, 0.8)
const LINE_THICKNESS = 3.0

func _ready():
	hide()
	grid_container.draw.connect(_on_grid_draw)

func init_milestones():
	# Clean up old elements
	for child in grid_container.get_children():
		child.queue_free()
	milestone_elements.clear()

	var max_x = 0
	var max_y = 0

	for data in all_milestones:
		if not data: continue

		if data.id == "":
			data.id = str(randi())

		var state: MilestoneState
		if milestone_states.has(data.id):
			state = milestone_states[data.id]
		else:
			state = MilestoneState.new()
			state.milestone_id = data.id
			milestone_states[data.id] = state

		var ui_elem = milestone_prefab.instantiate()
		grid_container.add_child(ui_elem)

		# Position based on grid coords
		ui_elem.position = Vector2(data.grid_position.x * GRID_SPACING_X, data.grid_position.y * GRID_SPACING_Y)

		var is_locked = _is_milestone_locked(data)
		ui_elem.setup(data, state, is_locked)
		ui_elem.claim_reward.connect(_on_claim_reward)
		ui_elem.toggle_pin.connect(_on_toggle_pin)
		milestone_elements[data.id] = ui_elem

		if ui_elem.position.x > max_x: max_x = ui_elem.position.x
		if ui_elem.position.y > max_y: max_y = ui_elem.position.y

	grid_container.custom_minimum_size = Vector2(max_x + GRID_SPACING_X, max_y + GRID_SPACING_Y)
	grid_container.queue_redraw()
	update_main_gui_milestones()

func _is_milestone_locked(data: MilestoneData) -> bool:
	for prereq_id in data.prerequisites:
		if not milestone_states.has(prereq_id) or not milestone_states[prereq_id].is_completed:
			return true
	return false

func _get_border_offset(dir: Vector2, size: Vector2) -> Vector2:
	if dir.length() == 0:
		return Vector2.ZERO
	# Calculate the intersection of a ray from the center (0,0) with direction `dir`
	# against an axis-aligned bounding box of `size` centered at (0,0).
	var half_size = size / 2.0
	var t_x = INF
	if abs(dir.x) > 0.001:
		t_x = half_size.x / abs(dir.x)

	var t_y = INF
	if abs(dir.y) > 0.001:
		t_y = half_size.y / abs(dir.y)

	var t = min(t_x, t_y)
	return dir * t

func _on_grid_draw():
	# Draw lines between prerequisites and targets
	for data in all_milestones:
		if not data or not milestone_elements.has(data.id): continue

		var target_elem = milestone_elements[data.id]
		var target_pos = target_elem.position + target_elem.size / 2.0

		for prereq_id in data.prerequisites:
			if milestone_elements.has(prereq_id):
				var prereq_elem = milestone_elements[prereq_id]
				var prereq_pos = prereq_elem.position + prereq_elem.size / 2.0

				# Adjust start/end slightly to not overlap the card fully
				var dir = (target_pos - prereq_pos).normalized()
				var start_offset = prereq_pos + _get_border_offset(dir, prereq_elem.size)
				var end_offset = target_pos - _get_border_offset(dir, target_elem.size)

				grid_container.draw_line(start_offset, end_offset, LINE_COLOR, LINE_THICKNESS, true)

				# Draw small arrow head
				var arrow_size = 15.0
				var p1 = end_offset - dir * arrow_size + dir.orthogonal() * arrow_size * 0.5
				var p2 = end_offset - dir * arrow_size - dir.orthogonal() * arrow_size * 0.5
				grid_container.draw_polygon(PackedVector2Array([end_offset, p1, p2]), PackedColorArray([LINE_COLOR]))


var local_player: Node = null

func get_local_player() -> Node:
	if local_player and is_instance_valid(local_player):
		return local_player
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.is_multiplayer_authority():
			local_player = p
			return local_player
	return null


func handle_milestone_event(action: String, item_data: ItemData = null, artifact_data: ArtifactData = null):
	var updated = false
	for data in all_milestones:
		if not data: continue

		var state = milestone_states.get(data.id)
		if not state or state.is_completed or _is_milestone_locked(data):
			continue

		if data.action != action:
			continue

		var match_item = false
		if action == "craft" and artifact_data:
			if data.specific_artifact and data.specific_artifact.resource_path == artifact_data.resource_path:
				match_item = true
		elif item_data:
			if data.any_item:
				match_item = true
			elif data.specific_item != null:
				match_item = (data.specific_item.resource_path == item_data.resource_path)
			else:
				match_item = (data.item_type == item_data.item_value_type)

		if match_item:
			state.current_count += 1
			if state.current_count >= data.target_count:
				state.current_count = data.target_count
				state.is_completed = true
				
				var p = get_local_player()
				if p and p.has_node("PlayerUI/NotificationArea"):
					p.get_node("PlayerUI/NotificationArea").display_message("Milestone Completed: " + data.title)
				# Unlocking might affect other milestones
				_update_all_locks()

			if milestone_elements.has(data.id):
				milestone_elements[data.id].update_ui()
			updated = true

	if updated:
		save_milestones()
		update_main_gui_milestones()

func _update_all_locks():
	for data in all_milestones:
		if not data or not milestone_elements.has(data.id): continue
		var is_locked = _is_milestone_locked(data)
		var elem = milestone_elements[data.id]
		elem.is_locked = is_locked
		elem.update_ui()

func _on_toggle_pin(milestone_id: String):
	var state = milestone_states.get(milestone_id)
	if not state: return

	if state.is_pinned:
		state.is_pinned = false
	else:
		state.is_pinned = true
		state.pin_timestamp = Time.get_unix_time_from_system()

	if milestone_elements.has(milestone_id):
		milestone_elements[milestone_id].update_ui()

	save_milestones()
	update_main_gui_milestones()

func _on_claim_reward(milestone_id: String):
	var state = milestone_states.get(milestone_id)
	if state and state.is_completed and not state.reward_claimed:
		state.reward_claimed = true
		if milestone_elements.has(milestone_id):
			milestone_elements[milestone_id].update_ui()

		# Grant reward logic
		var data = null
		for m in all_milestones:
			if m and m.id == milestone_id:
				data = m
				break

		if data:
			var p = get_local_player()
			if p:
				if data.reward_type == "money" and data.reward_money > 0:
					p.receive_money(data.reward_money)
				elif data.reward_type == "recipe" and data.reward_recipe:
					p.learn_recipe(data.reward_recipe)
				elif data.reward_type == "item" and data.reward_item:
					if p.has_method("grant_item"):
						p.grant_item(data.reward_item)

		save_milestones()
		update_main_gui_milestones()

func update_main_gui_milestones():
	var p = get_local_player()
	if not p or not p.has_node("PlayerUI/MainMilestonesContainer"): return
	var main_container = p.get_node("PlayerUI/MainMilestonesContainer")
	for child in main_container.get_children():
		child.queue_free()

	var pinned_milestones = []
	for data in all_milestones:
		if not data: continue
		var state = milestone_states.get(data.id)
		if state and state.is_pinned and not state.reward_claimed:
			pinned_milestones.append({"data": data, "state": state})

	# Sort by pin timestamp
	pinned_milestones.sort_custom(func(a, b): return a.state.pin_timestamp < b.state.pin_timestamp)

	for m in pinned_milestones:
		var ui_elem = milestone_prefab.instantiate()
		main_container.add_child(ui_elem)
		ui_elem.setup(m.data, m.state, false)
		ui_elem.set_is_main_gui(true)

func get_save_path() -> String:
	var p = get_local_player()
	if p and p.has_method("get_save_path"):
		var base_path = p.get_save_path()
		return base_path.replace(".save", "_milestones.json")
	return "user://milestones.json"

func save_milestones():
	var save_dict = {}
	for id in milestone_states:
		save_dict[id] = milestone_states[id].to_dict()

	var file = FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()

func load_milestones():
	var path = get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var parsed = JSON.parse_string(content)
			if parsed is Dictionary:
				for id in parsed:
					var state = MilestoneState.new()
					state.from_dict(parsed[id])
					milestone_states[id] = state
			file.close()
	init_milestones()
