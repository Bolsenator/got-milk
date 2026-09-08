extends Node

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menu.tscn")

func load_level() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world/level.tscn")

func register_main_menu_ui(main_menu: Control) -> void:
	main_menu.play_pressed.connect(on_play_game)
	main_menu.quit_pressed.connect(on_quit_game)

func register_level_signals(node: Node) -> void:
	node.restart.connect(on_restart)
	node.quit.connect(on_quit_game)

func on_play_game() -> void:
	load_level()

func on_restart() -> void:
	load_level()

func on_quit_game() -> void:
	get_tree().quit()
