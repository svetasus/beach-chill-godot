extends PanelContainer

signal claim_reward(task_id, reward_money)
signal toggle_pin(task_id)

var task_data: TaskData
var task_state: TaskState
var is_main_gui: bool = false

@onready var desc_label = $MarginContainer/VBoxContainer/HeaderHBox/DescLabel
@onready var pin_button = $MarginContainer/VBoxContainer/HeaderHBox/PinButton
@onready var count_label = $MarginContainer/VBoxContainer/CountLabel
@onready var reward_label = $MarginContainer/VBoxContainer/RewardLabel

# Standard styling
var normal_style = StyleBoxFlat.new()
var completed_style = StyleBoxFlat.new()
var claimed_style = StyleBoxFlat.new()

func _ready():
	# Setup styles
	normal_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.4, 0.4, 0.4, 1.0)

	completed_style.bg_color = Color(0.2, 0.6, 0.2, 0.8)
	completed_style.set_border_width_all(2)
	completed_style.border_color = Color(0.4, 0.8, 0.4, 1.0)

	claimed_style.bg_color = Color(0.1, 0.3, 0.1, 0.8)
	claimed_style.set_border_width_all(2)
	claimed_style.border_color = Color(0.2, 0.4, 0.2, 1.0)

	add_theme_stylebox_override("panel", normal_style)

	pin_button.pressed.connect(_on_pin_pressed)

func set_is_main_gui(is_main: bool):
	is_main_gui = is_main
	if is_main_gui:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		pin_button.hide()
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pin_button.show()

func setup(data: TaskData, state: TaskState):
	task_data = data
	task_state = state

	# Generate nice description
	var action_str = "Gather"
	if task_data.action == "sell":
		action_str = "Sell"

	var item_str = ""
	if task_data.specific_item:
		item_str = task_data.specific_item.display_name
	elif task_data.any_item:
		item_str = "any item"
	else:
		match task_data.item_type:
			ItemData.ItemValueType.COMMON: item_str = "Common item"
			ItemData.ItemValueType.RARE: item_str = "Rare item"
			ItemData.ItemValueType.EPIC: item_str = "Epic item"
			ItemData.ItemValueType.ARTIFACT: item_str = "Artifact item"

	if task_data.description != "Task description" and task_data.description != "":
		desc_label.text = task_data.description
	else:
		desc_label.text = action_str + " " + str(task_data.target_count) + " " + item_str

	reward_label.text = "Reward: $" + str(task_data.reward_money)

	update_ui()

func _on_pin_pressed():
	toggle_pin.emit(task_data.id)

func update_ui():
	count_label.text = str(task_state.current_count) + " / " + str(task_data.target_count)

	if task_state.is_pinned:
		pin_button.text = "Unpin"
	else:
		pin_button.text = "Pin"

	if task_state.reward_claimed:
		add_theme_stylebox_override("panel", claimed_style)
		count_label.text = "Completed (Claimed)"
	elif task_state.is_completed:
		add_theme_stylebox_override("panel", completed_style)
		count_label.text = "Completed! Click to claim."
	else:
		add_theme_stylebox_override("panel", normal_style)

func _gui_input(event):
	if is_main_gui:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if task_state.is_completed and not task_state.reward_claimed:
			# task_state.reward_claimed = true
			# update_ui()
			claim_reward.emit(task_data.id, task_data.reward_money)
