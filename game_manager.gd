extends Node

func _ready():
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menu.tscn")

func load_level():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world/level.tscn")

func register_main_menu_ui(main_menu: Control):
	main_menu.play_pressed.connect(_on_play_game)
	main_menu.quit_pressed.connect(_on_quit_game)

func register_pause_ui(pause_ui: Control):
	pause_ui.restart.connect(_on_restart)
	pause_ui.quit.connect(_on_quit_game)

func register_game_over_ui(game_over_ui: Control):
	game_over_ui.restart.connect(_on_restart)
	game_over_ui.quit.connect(_on_quit_game)

func register_level_complete_ui(level_complete_ui: Control):
	level_complete_ui.restart.connect(_on_restart)
	level_complete_ui.quit.connect(_on_quit_game)

func _on_play_game():
	load_level()

func _on_restart():
	load_level()

func _on_quit_game():
	get_tree().quit()
