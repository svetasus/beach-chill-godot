import re

with open('scripts/player.gd', 'r') as f:
    content = f.read()

# Replace references to TaskListUI and MilestoneListUI paths
content = content.replace('$PlayerUI/TaskListUI', '$PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/TaskListUI')
content = content.replace('$PlayerUI/MilestoneListUI', '$PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI')

# Replace the toggle logic in player.gd
toggle_tasks_original = """func toggle_tasks():
	if not is_multiplayer_authority(): return

	var tasks_ui = $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/TaskListUI
	if not tasks_ui: return

	tasks_ui.visible = !tasks_ui.visible

	if tasks_ui.visible:
		var inv_ui = $PlayerUI/CollectionUI
		if inv_ui: inv_ui.visible = false
		var milestones_ui = $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI
		if milestones_ui: milestones_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"""

toggle_milestones_original = """func toggle_milestones():
	if not is_multiplayer_authority(): return

	var milestones_ui = $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI
	if not milestones_ui: return

	milestones_ui.visible = !milestones_ui.visible

	if milestones_ui.visible:
		var inv_ui = $PlayerUI/InventoryUI
		if inv_ui: inv_ui.visible = false
		var tasks_ui = $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/TaskListUI
		if tasks_ui: tasks_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"""

toggle_tasks_new = """func toggle_tasks():
	if not is_multiplayer_authority(): return

	var progression_ui = $PlayerUI/ProgressionUI
	if not progression_ui: return

	if progression_ui.visible and progression_ui.current_tab == "Tasks":
		progression_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		progression_ui.visible = true
		progression_ui.set_tab("Tasks")
		var inv_ui = $PlayerUI/CollectionUI
		if inv_ui: inv_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE"""

toggle_milestones_new = """func toggle_milestones():
	if not is_multiplayer_authority(): return

	var progression_ui = $PlayerUI/ProgressionUI
	if not progression_ui: return

	if progression_ui.visible and progression_ui.current_tab == "Milestones":
		progression_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		progression_ui.visible = true
		progression_ui.set_tab("Milestones")
		var inv_ui = $PlayerUI/CollectionUI
		if inv_ui: inv_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE"""


content = content.replace(toggle_tasks_original, toggle_tasks_new)
content = content.replace(toggle_milestones_original, toggle_milestones_new)

# Update CollectionUI toggle to close ProgressionUI instead of its children
collection_ui_old = """	if inv_ui.visible:
		var tasks_ui = $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/TaskListUI
		if tasks_ui: tasks_ui.visible = false
		var milestones_ui = $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI
		if milestones_ui: milestones_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE"""

collection_ui_new = """	if inv_ui.visible:
		var prog_ui = $PlayerUI/ProgressionUI
		if prog_ui: prog_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE"""

content = content.replace(collection_ui_old, collection_ui_new)


# Update ui_cancel logic
ui_cancel_old = """		if $PlayerUI/CollectionUI != null and $PlayerUI/CollectionUI.visible:
			toggle_collection()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)"""

ui_cancel_new = """		if $PlayerUI/CollectionUI != null and $PlayerUI/CollectionUI.visible:
			toggle_collection()
		elif $PlayerUI/ProgressionUI != null and $PlayerUI/ProgressionUI.visible:
			if $PlayerUI/ProgressionUI.current_tab == "Tasks":
				toggle_tasks()
			else:
				toggle_milestones()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)"""

content = content.replace(ui_cancel_old, ui_cancel_new)

# Update UI visibility check
ui_open_old = """var is_ui_open = (current_ui != null and is_instance_valid(current_ui)) or ($PlayerUI/CollectionUI != null and $PlayerUI/CollectionUI.visible) or ($PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/TaskListUI != null and $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/TaskListUI.visible) or ($PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI != null and $PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer/MilestoneListUI.visible)"""
ui_open_new = """var is_ui_open = (current_ui != null and is_instance_valid(current_ui)) or ($PlayerUI/CollectionUI != null and $PlayerUI/CollectionUI.visible) or ($PlayerUI/ProgressionUI != null and $PlayerUI/ProgressionUI.visible)"""

content = content.replace(ui_open_old, ui_open_new)

with open('scripts/player.gd', 'w') as f:
    f.write(content)
