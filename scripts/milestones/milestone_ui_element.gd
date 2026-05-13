extends PanelContainer

signal claim_reward(milestone_id)
signal toggle_pin(milestone_id)

var milestone_data: MilestoneData
var milestone_state: MilestoneState
var is_locked: bool = false
var is_main_gui: bool = false

@onready var icon_rect = $MarginContainer/HBoxContainer/IconRect
@onready var desc_vbox = $MarginContainer/HBoxContainer/DescVBox
@onready var title_label = $MarginContainer/HBoxContainer/DescVBox/HeaderHBox/TitleLabel
@onready var pin_button = $MarginContainer/HBoxContainer/DescVBox/HeaderHBox/PinButton
@onready var desc_label = $MarginContainer/HBoxContainer/DescVBox/DescLabel
@onready var count_label = $MarginContainer/HBoxContainer/DescVBox/CountLabel
@onready var reward_label = $MarginContainer/HBoxContainer/DescVBox/RewardLabel

# Standard styling
var normal_style = StyleBoxFlat.new()
var completed_style = StyleBoxFlat.new()
var claimed_style = StyleBoxFlat.new()
var locked_style = StyleBoxFlat.new()

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

	locked_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	locked_style.set_border_width_all(2)
	locked_style.border_color = Color(0.2, 0.2, 0.2, 1.0)

	add_theme_stylebox_override("panel", normal_style)

	pin_button.pressed.connect(_on_pin_pressed)

func set_is_main_gui(is_main: bool):
	is_main_gui = is_main
	if is_main_gui:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		pin_button.hide()
		desc_label.hide()
		reward_label.hide()
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pin_button.show()
		desc_label.show()
		reward_label.show()

func setup(data: MilestoneData, state: MilestoneState, locked: bool = false):
	milestone_data = data
	milestone_state = state
	is_locked = locked

	title_label.text = milestone_data.title
	desc_label.text = milestone_data.description

	if milestone_data.icon:
		icon_rect.texture = milestone_data.icon

	reward_label.text = "Reward: " + milestone_data.reward_description

	update_ui()

func _on_pin_pressed():
	if is_locked: return
	toggle_pin.emit(milestone_data.id)

func update_ui():
	if is_locked:
		add_theme_stylebox_override("panel", locked_style)
		count_label.text = "Locked"
		modulate = Color(0.5, 0.5, 0.5, 1.0) # Grayed out
		pin_button.disabled = true
		return
	else:
		modulate = Color(1, 1, 1, 1)
		pin_button.disabled = false

	count_label.text = str(milestone_state.current_count) + " / " + str(milestone_data.target_count)

	if milestone_state.is_pinned:
		pin_button.text = "Unpin"
	else:
		pin_button.text = "Pin"

	if milestone_state.reward_claimed:
		add_theme_stylebox_override("panel", claimed_style)
		count_label.text = "Completed (Claimed)"
	elif milestone_state.is_completed:
		add_theme_stylebox_override("panel", completed_style)
		count_label.text = "Completed! Click to claim."
	else:
		add_theme_stylebox_override("panel", normal_style)

func _gui_input(event):
	if is_main_gui or is_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if milestone_state.is_completed and not milestone_state.reward_claimed:
			claim_reward.emit(milestone_data.id)
