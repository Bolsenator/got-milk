extends Control

@onready var exp_bar_ui = $ExpBar
@onready var time_elapsed_ui = $TimeElapsed

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	player.milk_changed.connect(_on_milk_changed)
	exp_bar_ui.max_value = player.max_milk
	exp_bar_ui.value = player.current_milk

func _on_milk_changed(new_milk, max_milk):
	exp_bar_ui.max_value = max_milk
	exp_bar_ui.value = new_milk

func update_time_elapsed(time_elapsed: float):
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	time_elapsed_ui.text = str("%02d:%02d" % [minutes, seconds])
