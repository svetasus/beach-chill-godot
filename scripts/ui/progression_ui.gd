extends Control

var current_tab: String = "Tasks" # "Tasks" or "Milestones"

var tasks_ui
var milestones_ui
var recipes_ui

func _ready():
	self.hide()
	tasks_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/TaskListUI")
	milestones_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI")
	recipes_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/RecipeListUI")
	if tasks_ui: tasks_ui.hide()
	if milestones_ui: milestones_ui.hide()
	if recipes_ui: recipes_ui.hide()

	var tasks_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/TasksTab")
	var milestones_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/MilestonesTab")
	var recipes_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/RecipesTab")

	if tasks_btn:
		tasks_btn.pressed.connect(func(): set_tab("Tasks"))
	if milestones_btn:
		milestones_btn.pressed.connect(func(): set_tab("Milestones"))
	if recipes_btn:
		recipes_btn.pressed.connect(func(): set_tab("Recipes"))

	update_tab_styles()

func update_tab_styles():
	var tasks_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/TasksTab")
	var milestones_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/MilestonesTab")
	var recipes_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/RecipesTab")

	var panel = get_node_or_null("PanelContainer")
	if panel:
		panel.theme_type_variation = "WindowPanel"

	if tasks_btn:
		if current_tab == "Tasks":
			tasks_btn.theme_type_variation = "ActiveTabBtn"
		else:
			tasks_btn.theme_type_variation = "InactiveTabBtn"

	if milestones_btn:
		if current_tab == "Milestones":
			milestones_btn.theme_type_variation = "ActiveTabBtn"
		else:
			milestones_btn.theme_type_variation = "InactiveTabBtn"

	if recipes_btn:
		if current_tab == "Recipes":
			recipes_btn.theme_type_variation = "ActiveTabBtn"
		else:
			recipes_btn.theme_type_variation = "InactiveTabBtn"

func set_tab(tab_name: String):
	current_tab = tab_name
	update_tab_styles()
	refresh_ui()

func refresh_ui():
	if not tasks_ui: tasks_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/TaskListUI")
	if not milestones_ui: milestones_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI")
	if not recipes_ui: recipes_ui = get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/RecipeListUI")

	if current_tab == "Tasks":
		if tasks_ui: tasks_ui.show()
		if milestones_ui: milestones_ui.hide()
		if recipes_ui: recipes_ui.hide()
	elif current_tab == "Milestones":
		if tasks_ui: tasks_ui.hide()
		if milestones_ui: milestones_ui.show()
		if recipes_ui: recipes_ui.hide()
	elif current_tab == "Recipes":
		if tasks_ui: tasks_ui.hide()
		if milestones_ui: milestones_ui.hide()
		if recipes_ui:
			recipes_ui.show()
			if recipes_ui.has_method("refresh_ui"):
				recipes_ui.refresh_ui()
