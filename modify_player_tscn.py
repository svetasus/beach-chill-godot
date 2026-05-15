import re

with open('scenes/features/player.tscn', 'r') as f:
    content = f.read()

# Add ext_resource for ProgressionUI
progression_ui_resource = '[ext_resource type="PackedScene" uid="uid://cxab321300000" path="res://scenes/features/UI/progression_ui.tscn" id="ProgressionUI_ext"]\n'

# Find the last ext_resource to insert after
match = list(re.finditer(r'\[ext_resource .*\]', content))[-1]
content = content[:match.end()] + '\n' + progression_ui_resource + content[match.end():]


# Find TaskListUI and MilestoneListUI and replace them
task_list_str = '''[node name="TaskListUI" parent="PlayerUI" instance=ExtResource("7_tasklist")]
task_prefab = ExtResource("8_taskelem")
default_tasks = Array[ExtResource("2_task_data")]([ExtResource("10_task1"), ExtResource("11_task2"), ExtResource("13_task3"), ExtResource("9_f4yut"), ExtResource("12_vlnj5")])'''

milestone_list_str = '''[node name="MilestoneListUI" parent="PlayerUI" instance=ExtResource("18_milestonelist")]'''


progression_ui_str = '''[node name="ProgressionUI" parent="PlayerUI" instance=ExtResource("ProgressionUI_ext")]

[node name="TaskListUI" parent="PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer" index="0" instance=ExtResource("7_tasklist")]
layout_mode = 1
task_prefab = ExtResource("8_taskelem")
default_tasks = Array[ExtResource("2_task_data")]([ExtResource("10_task1"), ExtResource("11_task2"), ExtResource("13_task3"), ExtResource("9_f4yut"), ExtResource("12_vlnj5")])

[node name="MilestoneListUI" parent="PlayerUI/ProgressionUI/PanelContainer/VBoxContainer/ContentContainer" index="1" instance=ExtResource("18_milestonelist")]
layout_mode = 1'''


content = content.replace(task_list_str, progression_ui_str)
content = content.replace(milestone_list_str, "")
# remove empty lines
content = re.sub(r'\n\s*\n', '\n\n', content)

with open('scenes/features/player.tscn', 'w') as f:
    f.write(content)
