extends Control

@onready var exp_bar_ui = $ExpBar
@onready var time_elapsed_ui = $TimeElapsed

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	player.exp_changed.connect(_on_exp_changed)
	exp_bar_ui.max_value = player.max_exp
	exp_bar_ui.value = player.current_exp

func _on_exp_changed(new_exp, max_exp):
	exp_bar_ui.max_value = max_exp
	exp_bar_ui.value = new_exp

func update_time_elapsed(time_elapsed: float):
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	time_elapsed_ui.text = str("%02d:%02d" % [minutes, seconds])
