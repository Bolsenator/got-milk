extends Control

signal restart()
signal quit()

func _on_restart_pressed() -> void:
	restart.emit()


func _on_quit_pressed() -> void:
	quit.emit()
