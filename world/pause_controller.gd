extends Node

enum PauseReason { NONE, MANUAL, LEVEL_UP, GAME_OVER, LEVEL_COMPLETED }

var current_pause_reason: PauseReason = PauseReason.NONE

signal game_paused()
signal game_resumed()

func toggle_pause(_new_pause_reason: PauseReason) -> void:
	get_tree().paused = !get_tree().paused
	current_pause_reason = _new_pause_reason
	if current_pause_reason == PauseReason.MANUAL:
		game_paused.emit()
	elif current_pause_reason == PauseReason.NONE:
		game_resumed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		# If not paused, attempt to pause
		if current_pause_reason == PauseReason.NONE:
			toggle_pause(PauseReason.MANUAL)
		# If manually paused, attempt to resume
		elif current_pause_reason == PauseReason.MANUAL:
			toggle_pause(PauseReason.NONE)
		# If paused for any other reason, silently ignore input
		
		get_viewport().set_input_as_handled()
