extends Control

signal resume()
signal restart()
signal quit()

func _on_resume_pressed() -> void:
	resume.emit()

func _on_restart_pressed() -> void:
	restart.emit()

func _on_quit_pressed() -> void:
	quit.emit()
