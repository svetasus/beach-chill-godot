extends PanelContainer

@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var main_hbox = $MarginContainer/VBoxContainer/MainHBox
@onready var locked_panel = $MarginContainer/VBoxContainer/LockedPanel

var plus_texture = preload("res://textures/icons/plus.png")
var equals_texture = preload("res://textures/icons/ravno.png")

var normal_style = StyleBoxFlat.new()

func _ready():
	normal_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	normal_style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", normal_style)

func setup(recipe: ArtifactData, is_unlocked: bool, is_crafted: bool, items_held: Dictionary):
	var r_name = recipe.recipe_name
	if not r_name or r_name == "":
		if recipe.result_item:
			r_name = recipe.result_item.display_name

	name_label.text = r_name if r_name else "???"
	if r_name:
		tooltip_text = r_name

	if not is_unlocked:
		main_hbox.hide()
		locked_panel.show()
		locked_panel.get_node("QuestionMark").text = "Locked"
		return

	main_hbox.show()
	locked_panel.hide()
	locked_panel.get_node("QuestionMark").text = ""

	# Create icons for ingredients
	for i in range(recipe.required_parts.size()):
		var part = recipe.required_parts[i]
		if part and part.item_icon:
			var is_discovered = items_held.has(part.name)
			_add_icon(part.item_icon, not is_discovered, part.display_name if is_discovered else "???")
		else:
			_add_icon(null, false, "Unknown Part")

		# Add plus or equals sign
		if i < recipe.required_parts.size() - 1:
			_add_symbol(plus_texture)
		else:
			_add_symbol(equals_texture)

	# Add result icon
	if recipe.result_item and recipe.result_item.item_icon:
		_add_icon(recipe.result_item.item_icon, not is_crafted, recipe.result_item.display_name if is_crafted else "???")

func _add_icon(tex: Texture2D, is_silhouette: bool, tip: String):
	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(64, 64)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = tex
	rect.tooltip_text = tip
	if is_silhouette:
		rect.modulate = Color(0, 0, 0, 0.776)
	main_hbox.add_child(rect)

func _add_symbol(tex: Texture2D):
	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(32, 64)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = tex
	main_hbox.add_child(rect)
