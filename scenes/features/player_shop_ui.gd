extends Control


@onready var grid = $Panel/GridContainer
var target_chest: Node3D

var slot_prefab: PackedScene = preload("res://ui/inventorySlot.tscn")
