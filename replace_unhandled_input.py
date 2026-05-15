import re

def remove_unhandled_input(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    content = re.sub(r'func _unhandled_input\(event: InputEvent\) -> void:\n\s*if visible and event\.is_action_pressed\("ui_cancel"\):\n\s*get_viewport\(\)\.set_input_as_handled\(\)\n\s*if owner and owner\.has_method\("toggle_.*"\):\n\s*owner\.toggle_.*\(\)', '', content)

    with open(filepath, 'w') as f:
        f.write(content)

remove_unhandled_input('scripts/task_list_ui.gd')
remove_unhandled_input('scripts/milestones/milestone_list_ui.gd')
