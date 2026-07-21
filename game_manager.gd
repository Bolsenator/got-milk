extends Node

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menu.tscn")

func load_level() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world/level.tscn")

func register_main_menu_ui(main_menu: Control) -> void:
	main_menu.play_pressed.connect(_on_play_game)
	main_menu.quit_pressed.connect(_on_quit_game)

func register_pause_ui(pause_ui: Control) -> void:
	pause_ui.restart.connect(_on_restart)
	pause_ui.quit.connect(_on_quit_game)

func register_game_over_ui(game_over_ui: Control) -> void:
	game_over_ui.restart.connect(_on_restart)
	game_over_ui.quit.connect(_on_quit_game)

func register_level_complete_ui(level_complete_ui: Control) -> void:
	level_complete_ui.restart.connect(_on_restart)
	level_complete_ui.quit.connect(_on_quit_game)

func _on_play_game() -> void:
	load_level()

func _on_restart() -> void:
	load_level()

func _on_quit_game() -> void:
	get_tree().quit()
