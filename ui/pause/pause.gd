extends Control

signal close_pause_menu_pressed()
signal restart_pressed()
signal quit_pressed()

func _ready() -> void:
	GameManager.register_pause_ui(self)

func _on_restart_pressed() -> void:
	restart_pressed.emit()

func _on_quit_pressed() -> void:
	quit_pressed.emit()

func _on_close_menu_pressed() -> void:
	close_pause_menu_pressed.emit()
