content = """[gd_scene load_steps=2 format=3 uid="uid://df6o8m2p5q3w7"]

[ext_resource type="Script" uid="uid://bnu10lfnqrhsu" path="res://scripts/task_list_ui.gd" id="1_task_list_ui"]

[sub_resource type="StyleBoxEmpty" id="StyleBoxEmpty_p0"]

[node name="TaskListUI" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_task_list_ui")

[node name="PanelContainer" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("StyleBoxEmpty_p0")

[node name="VBoxContainer" type="VBoxContainer" parent="PanelContainer"]
layout_mode = 2

[node name="TitleLabel" type="Label" parent="PanelContainer/VBoxContainer"]
visible = false
layout_mode = 2
theme_override_font_sizes/font_size = 35
text = "Tasks"
horizontal_alignment = 1

[node name="ScrollContainer" type="ScrollContainer" parent="PanelContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3

[node name="TasksContainer" type="VBoxContainer" parent="PanelContainer/VBoxContainer/ScrollContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 10
"""
with open('scenes/features/UI/tasks/task_list_ui.tscn', 'w') as f:
    f.write(content)
