extends MarginContainer

@onready var section_name_label = $HBoxContainer/SectionNameLabel
@onready var timer_label = $HBoxContainer/TimerLabel

var section_data: TaskSectionData
var section_state: TaskSectionState

func setup(data: TaskSectionData, state: TaskSectionState):
	section_data = data
	section_state = state
	section_name_label.text = section_data.section_name

	if not section_data.has_timer:
		timer_label.hide()
	else:
		timer_label.show()
		update_timer_label()

func _process(_delta):
	if section_data and section_data.has_timer:
		update_timer_label()

func update_timer_label():
	if not section_state:
		return

	var current_time = Time.get_unix_time_from_system()
	var time_left = int(section_state.next_refresh_time - current_time)

	if time_left <= 0:
		timer_label.text = "Refreshing..."
		return

	var days = time_left / 86400
	var hours = (time_left % 86400) / 3600
	var minutes = (time_left % 3600) / 60
	var seconds = time_left % 60

	var weeks = days / 7
	var remaining_days = days % 7

	var time_str = ""

	if weeks > 0:
		time_str = str(weeks) + "w " + str(remaining_days) + "d"
	elif days > 0:
		time_str = str(days) + "d " + str(hours) + "h"
	elif hours > 0:
		time_str = str(hours) + "h " + str(minutes) + "m"
	elif minutes > 0:
		time_str = str(minutes) + "m " + str(seconds) + "s"
	else:
		time_str = str(seconds) + "s"

	timer_label.text = time_str
