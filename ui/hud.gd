extends Control

@onready var milk_bar = $HBoxContainer/MilkBar

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	player.milk_changed.connect(_on_milk_changed)
	milk_bar.max_value = player.max_milk
	milk_bar.value = player.current_milk

func _on_milk_changed(new_milk, max_milk):
	milk_bar.max_value = max_milk
	milk_bar.value = new_milk
