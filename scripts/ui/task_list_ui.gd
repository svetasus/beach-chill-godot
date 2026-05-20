extends Control

@export var task_prefab: PackedScene
@export var default_tasks: Array[TaskData] = []

var task_states: Dictionary = {} # task_id -> TaskState
var task_elements: Dictionary = {} # task_id -> TaskUIElement

@onready var tasks_container = $PanelContainer/VBoxContainer/ScrollContainer/TasksContainer

func _ready():
	hide()

func init_tasks():
	# Clean up old elements
	for child in tasks_container.get_children():
		child.queue_free()
	task_elements.clear()

	for task_data in default_tasks:
		if not task_data: continue

		# Give it a random ID if it doesn't have one (for new tasks)
		if task_data.id == "":
			task_data.id = str(randi())

		var state: TaskState
		if task_states.has(task_data.id):
			state = task_states[task_data.id]
		else:
			state = TaskState.new()
			state.task_id = task_data.id
			task_states[task_data.id] = state

		var ui_elem = task_prefab.instantiate()
		tasks_container.add_child(ui_elem)
		ui_elem.setup(task_data, state)
		ui_elem.claim_reward.connect(_on_claim_reward)
		ui_elem.toggle_pin.connect(_on_toggle_pin)
		task_elements[task_data.id] = ui_elem

	update_main_gui_tasks()

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

func handle_task_event(action: String, item_data: ItemData):
	var updated = false
	for task_data in default_tasks:
		if not task_data: continue

		var state = task_states.get(task_data.id)
		if not state or state.is_completed:
			continue

		if task_data.action != action:
			continue

		var match_item = false
		if task_data.any_item:
			match_item = true
		elif task_data.specific_item != null:
			match_item = (task_data.specific_item.resource_path == item_data.resource_path)
		else:
			match_item = (task_data.item_type == item_data.item_value_type)

		if match_item:
			state.current_count += 1
			if state.current_count >= task_data.target_count:
				state.current_count = task_data.target_count
				state.is_completed = true
				var p = get_local_player()
				if p and p.has_node("PlayerUI/NotificationArea"):
					p.get_node("PlayerUI/NotificationArea").display_message("Task Completed!")

			if task_elements.has(task_data.id):
				task_elements[task_data.id].update_ui()
			updated = true

	if updated:
		save_tasks()
		update_main_gui_tasks()

func _on_toggle_pin(task_id: String):
	var state = task_states.get(task_id)
	if not state: return

	if state.is_pinned:
		state.is_pinned = false
	else:
		# Count currently pinned
		var pinned_count = 0
		for t_id in task_states:
			if task_states[t_id].is_pinned:
				pinned_count += 1

		if pinned_count >= 3:
			# Find oldest pinned
			var oldest_id = ""
			var oldest_time = INF
			for t_id in task_states:
				if task_states[t_id].is_pinned and task_states[t_id].pin_timestamp < oldest_time:
					oldest_time = task_states[t_id].pin_timestamp
					oldest_id = t_id

			if oldest_id != "":
				task_states[oldest_id].is_pinned = false
				if task_elements.has(oldest_id):
					task_elements[oldest_id].update_ui()

		state.is_pinned = true
		state.pin_timestamp = Time.get_unix_time_from_system()

	if task_elements.has(task_id):
		task_elements[task_id].update_ui()

	save_tasks()
	update_main_gui_tasks()

func _on_claim_reward(task_id: String, reward_money: int):
	var state = task_states.get(task_id)
	if state and state.is_completed and not state.reward_claimed:
		state.reward_claimed = true
		if task_elements.has(task_id):
			task_elements[task_id].update_ui()

		var p = get_local_player()
		if p and p.has_method("receive_money"):
			p.receive_money(reward_money)
		save_tasks()
		update_main_gui_tasks()

func update_main_gui_tasks():
	var p = get_local_player()
	if not p or not p.has_node("PlayerUI/MainTasksContainer"): return
	var main_container = p.get_node("PlayerUI/MainTasksContainer")

	# Clear existing
	for child in main_container.get_children():
		child.queue_free()

	# Filter active tasks (not reward claimed)
	var active_tasks = []
	for task_data in default_tasks:
		if not task_data: continue
		var state = task_states.get(task_data.id)
		if state and not state.reward_claimed:
			active_tasks.append({"data": task_data, "state": state})

	# Sort
	active_tasks.sort_custom(func(a, b):
		# 1. Pinned
		if a.state.is_pinned != b.state.is_pinned:
			return a.state.is_pinned # true comes before false

		# 2. Priority
		if a.data.task_priority != b.data.task_priority:
			return a.data.task_priority < b.data.task_priority # lower is better

		# 3. Completion percentage
		var pct_a = float(a.state.current_count) / float(a.data.target_count) if a.data.target_count > 0 else 0.0
		var pct_b = float(b.state.current_count) / float(b.data.target_count) if b.data.target_count > 0 else 0.0
		if pct_a != pct_b:
			return pct_a > pct_b # higher is better

		return false
	)

	# Take top 3
	var top_tasks = active_tasks.slice(0, 3)

	for t in top_tasks:
		var ui_elem = task_prefab.instantiate()
		main_container.add_child(ui_elem)
		ui_elem.setup(t.data, t.state)
		if ui_elem.has_method("set_is_main_gui"):
			ui_elem.set_is_main_gui(true)

func get_save_path() -> String:
	var p = get_local_player()
	if p and p.has_method("get_save_path"):
		var base_path = p.get_save_path()
		return base_path.replace(".save", "_tasks.json")
	return "user://tasks.json"

func save_tasks():
	var save_dict = {}
	for id in task_states:
		save_dict[id] = task_states[id].to_dict()

	var file = FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()

func load_tasks():
	var path = get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var parsed = JSON.parse_string(content)
			if parsed is Dictionary:
				for id in parsed:
					var state = TaskState.new()
					state.from_dict(parsed[id])
					task_states[id] = state
			file.close()
	init_tasks()
