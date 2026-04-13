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
		task_elements[task_data.id] = ui_elem

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
				if owner and owner.has_node("PlayerUI/NotificationArea"):
					owner.get_node("PlayerUI/NotificationArea").display_message("Task Completed!")

			if task_elements.has(task_data.id):
				task_elements[task_data.id].update_ui()
			updated = true

	if updated:
		save_tasks()

func _on_claim_reward(task_id: String, reward_money: int):
	var state = task_states.get(task_id)
	if state and state.is_completed and not state.reward_claimed:
		state.reward_claimed = true
		if task_elements.has(task_id):
			task_elements[task_id].update_ui()

		if owner and owner.has_method("receive_money"):
			# we assume owner is player.gd
			owner.receive_money(reward_money)
		save_tasks()

func get_save_path() -> String:
	if owner and owner.has_method("get_save_path"):
		var base_path = owner.get_save_path()
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

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if owner and owner.has_method("toggle_tasks"):
			owner.toggle_tasks()
