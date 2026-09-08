extends Control

signal close_pause_menu()
signal restart()
signal quit()

func _on_restart_pressed() -> void:
	restart.emit()

func _on_quit_pressed() -> void:
	quit.emit()

func _on_close_menu_pressed() -> void:
	close_pause_menu.emit()
