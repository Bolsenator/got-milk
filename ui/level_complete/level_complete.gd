extends Control

signal restart()
signal quit()

func _ready() -> void:
	GameManager.register_level_complete_ui(self)

func _on_restart_pressed() -> void:
	restart.emit()

func _on_quit_pressed() -> void:
	quit.emit()
