extends Control

signal play_pressed()
signal quit_pressed()

func _ready() -> void:
	GameManager.register_main_menu_ui(self)

func _on_play_pressed() -> void:
	play_pressed.emit()

func _on_quit_pressed() -> void:
	quit_pressed.emit()
