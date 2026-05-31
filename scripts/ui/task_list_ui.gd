extends Control

@export var task_prefab: PackedScene
@export var section_header_prefab: PackedScene
@export var sections: Array[TaskSectionData] = []

var task_states: Dictionary = {} # task_id -> TaskState
var task_elements: Dictionary = {} # task_id -> TaskUIElement
var section_states: Dictionary = {} # section_name -> TaskSectionState

@onready var tasks_container = $PanelContainer/VBoxContainer/ScrollContainer/TasksContainer

func _ready():
	hide()

func init_tasks():
	# Clean up old elements
	for child in tasks_container.get_children():
		child.queue_free()
	task_elements.clear()

	var current_time = Time.get_unix_time_from_system()

	for section_data in sections:
		if not section_data: continue

		# Make sure we have a state for this section
		var s_state: TaskSectionState
		if section_states.has(section_data.section_name):
			s_state = section_states[section_data.section_name]
		else:
			s_state = TaskSectionState.new()
			s_state.section_name = section_data.section_name
			section_states[section_data.section_name] = s_state

		# Check if we need to refresh tasks
		var needs_refresh = false
		if section_data.has_timer:
			if current_time >= s_state.next_refresh_time:
				needs_refresh = true
				s_state.next_refresh_time = current_time + section_data.timer_duration_seconds
		else:
			# If no timer, we only populate if empty
			if s_state.active_task_ids.is_empty():
				needs_refresh = true

		if needs_refresh:
			# Get old active ids to avoid picking them again if possible
			var old_active_ids = s_state.active_task_ids.duplicate()

			# Reset progress of old active tasks
			for old_id in s_state.active_task_ids:
				if task_states.has(old_id):
					var ts = task_states[old_id]
					ts.current_count = 0
					ts.is_completed = false
					ts.reward_claimed = false
					# Note: we can keep pin state if we want, or reset it. Let's reset it too.
					ts.is_pinned = false

			s_state.active_task_ids.clear()

			# Ensure IDs exist on all available tasks before processing
			for t_data in section_data.available_tasks:
				if t_data and t_data.id == "":
					t_data.id = str(randi())

			var available = section_data.available_tasks.duplicate()

			# Separate tasks into ones we didn't just have, and ones we did
			var unpicked_tasks = []
			var recently_picked_tasks = []
			for t_data in available:
				if not t_data: continue
				if old_active_ids.has(t_data.id):
					recently_picked_tasks.append(t_data)
				else:
					unpicked_tasks.append(t_data)

			unpicked_tasks.shuffle()
			recently_picked_tasks.shuffle()

			# Prioritize unpicked tasks
			var prioritized_available = unpicked_tasks + recently_picked_tasks

			for i in range(min(section_data.num_slots, prioritized_available.size())):
				var t_data = prioritized_available[i]
				s_state.active_task_ids.append(t_data.id)

				# Ensure that the newly picked tasks have their progress completely reset,
				# just in case this specific task was also picked in a previous cycle
				if task_states.has(t_data.id):
					var ts = task_states[t_data.id]
					ts.current_count = 0
					ts.is_completed = false
					ts.reward_claimed = false
					ts.is_pinned = false

		# Create UI header
		if section_header_prefab:
			var header = section_header_prefab.instantiate()
			tasks_container.add_child(header)
			header.setup(section_data, s_state)

		# Create UI elements for active tasks in this section
		for t_data in section_data.available_tasks:
			if not t_data: continue

			# Assign random ID if not set
			if t_data.id == "":
				t_data.id = str(randi())

			# Skip if not active in this section
			if not s_state.active_task_ids.has(t_data.id):
				continue

			var state: TaskState
			if task_states.has(t_data.id):
				state = task_states[t_data.id]
			else:
				state = TaskState.new()
				state.task_id = t_data.id
				task_states[t_data.id] = state

			var ui_elem = task_prefab.instantiate()
			tasks_container.add_child(ui_elem)
			ui_elem.setup(t_data, state)
			ui_elem.claim_reward.connect(_on_claim_reward)
			ui_elem.toggle_pin.connect(_on_toggle_pin)
			task_elements[t_data.id] = ui_elem

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

func _process(_delta):
	# Periodically check if any section timer expired while UI is open or running
	if visible:
		var current_time = Time.get_unix_time_from_system()
		var should_reinit = false
		for section_data in sections:
			if not section_data or not section_data.has_timer: continue
			var s_state = section_states.get(section_data.section_name)
			if s_state and current_time >= s_state.next_refresh_time:
				should_reinit = true
				break
		if should_reinit:
			init_tasks()

func get_all_active_task_data() -> Array[TaskData]:
	var result: Array[TaskData] = []
	for section_data in sections:
		if not section_data: continue
		var s_state = section_states.get(section_data.section_name)
		if not s_state: continue

		for t_data in section_data.available_tasks:
			if not t_data: continue
			if s_state.active_task_ids.has(t_data.id):
				result.append(t_data)
	return result

func handle_task_event(action: String, item_data: ItemData = null, artifact_data: ArtifactData = null):
	var updated = false
	var active_tasks = get_all_active_task_data()

	for task_data in active_tasks:
		var state = task_states.get(task_data.id)
		if not state or state.is_completed:
			continue

		if task_data.action != action:
			continue

		var match_item = false
		if action == "craft" and artifact_data:
			if task_data.specific_artifact and task_data.specific_artifact.resource_path == artifact_data.resource_path:
				match_item = true
			elif not task_data.specific_artifact:
				match_item = true # any artifact
		elif item_data:
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
	var all_active_data = get_all_active_task_data()

	for task_data in all_active_data:
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
	var states_dict = {}
	for id in task_states:
		states_dict[id] = task_states[id].to_dict()

	var sections_dict = {}
	for sec_name in section_states:
		sections_dict[sec_name] = section_states[sec_name].to_dict()

	save_dict["tasks"] = states_dict
	save_dict["sections"] = sections_dict

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
				# Backward compatibility with old save format
				if not parsed.has("tasks") and not parsed.has("sections"):
					for id in parsed:
						var state = TaskState.new()
						state.from_dict(parsed[id])
						task_states[id] = state
				else:
					var tasks_dict = parsed.get("tasks", {})
					for id in tasks_dict:
						var state = TaskState.new()
						state.from_dict(tasks_dict[id])
						task_states[id] = state

					var sections_dict = parsed.get("sections", {})
					for sec_name in sections_dict:
						var s_state = TaskSectionState.new()
						s_state.from_dict(sections_dict[sec_name])
						section_states[sec_name] = s_state

			file.close()
	init_tasks()
