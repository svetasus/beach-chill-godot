extends Control

var current_tab: String = "Tasks" # "Tasks" or "Milestones"

var active_style: StyleBoxFlat
var inactive_style: StyleBoxFlat
var window_style: StyleBoxFlat

var tasks_ui
var milestones_ui

func _ready():
	self.hide()
	tasks_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/TaskListUI")
	milestones_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI")
	if tasks_ui: tasks_ui.hide()
	if milestones_ui: milestones_ui.hide()

	_setup_styles()

	var tasks_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/TasksTab")
	var milestones_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/MilestonesTab")

	if tasks_btn:
		tasks_btn.pressed.connect(func(): set_tab("Tasks"))
	if milestones_btn:
		milestones_btn.pressed.connect(func(): set_tab("Milestones"))

	update_tab_styles()

func _setup_styles():
	var light_grey = Color(0.8, 0.8, 0.8, 1.0)
	var dark_grey = Color(0.5, 0.5, 0.5, 1.0)

	window_style = StyleBoxFlat.new()
	window_style.bg_color = light_grey
	window_style.set_corner_radius_all(8)
	window_style.content_margin_left = 20
	window_style.content_margin_right = 20
	window_style.content_margin_top = 20
	window_style.content_margin_bottom = 20

	var panel = get_node_or_null("PanelContainer")
	if panel:
		panel.add_theme_stylebox_override("panel", window_style)

	active_style = StyleBoxFlat.new()
	active_style.bg_color = light_grey
	active_style.set_corner_radius_all(8)
	active_style.corner_radius_bottom_left = 0
	active_style.corner_radius_bottom_right = 0
	active_style.content_margin_left = 30
	active_style.content_margin_right = 30
	active_style.content_margin_top = 15
	active_style.content_margin_bottom = 15

	inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = dark_grey
	inactive_style.set_corner_radius_all(8)
	inactive_style.content_margin_left = 30
	inactive_style.content_margin_right = 30
	inactive_style.content_margin_top = 15
	inactive_style.content_margin_bottom = 15

func update_tab_styles():
	var tasks_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/TasksTab")
	var milestones_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/MilestonesTab")

	var text_color = Color(0.1, 0.1, 0.1, 1.0)
	var inactive_text_color = Color(0.9, 0.9, 0.9, 1.0)

	if tasks_btn:
		tasks_btn.add_theme_font_size_override("font_size", 32)
		if current_tab == "Tasks":
			tasks_btn.add_theme_stylebox_override("normal", active_style)
			tasks_btn.add_theme_stylebox_override("hover", active_style)
			tasks_btn.add_theme_stylebox_override("pressed", active_style)
			tasks_btn.add_theme_color_override("font_color", text_color)
			tasks_btn.add_theme_color_override("font_hover_color", text_color)
			tasks_btn.add_theme_color_override("font_pressed_color", text_color)
		else:
			tasks_btn.add_theme_stylebox_override("normal", inactive_style)
			tasks_btn.add_theme_stylebox_override("hover", inactive_style)
			tasks_btn.add_theme_stylebox_override("pressed", inactive_style)
			tasks_btn.add_theme_color_override("font_color", inactive_text_color)
			tasks_btn.add_theme_color_override("font_hover_color", inactive_text_color)
			tasks_btn.add_theme_color_override("font_pressed_color", inactive_text_color)

	if milestones_btn:
		milestones_btn.add_theme_font_size_override("font_size", 32)
		if current_tab == "Milestones":
			milestones_btn.add_theme_stylebox_override("normal", active_style)
			milestones_btn.add_theme_stylebox_override("hover", active_style)
			milestones_btn.add_theme_stylebox_override("pressed", active_style)
			milestones_btn.add_theme_color_override("font_color", text_color)
			milestones_btn.add_theme_color_override("font_hover_color", text_color)
			milestones_btn.add_theme_color_override("font_pressed_color", text_color)
		else:
			milestones_btn.add_theme_stylebox_override("normal", inactive_style)
			milestones_btn.add_theme_stylebox_override("hover", inactive_style)
			milestones_btn.add_theme_stylebox_override("pressed", inactive_style)
			milestones_btn.add_theme_color_override("font_color", inactive_text_color)
			milestones_btn.add_theme_color_override("font_hover_color", inactive_text_color)
			milestones_btn.add_theme_color_override("font_pressed_color", inactive_text_color)

func set_tab(tab_name: String):
	current_tab = tab_name
	update_tab_styles()
	refresh_ui()

func refresh_ui():
	if not tasks_ui: tasks_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/TaskListUI")
	if not milestones_ui: milestones_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI")

	if current_tab == "Tasks":
		if tasks_ui: tasks_ui.show()
		if milestones_ui: milestones_ui.hide()
	elif current_tab == "Milestones":
		if tasks_ui: tasks_ui.hide()
		if milestones_ui: milestones_ui.show()
