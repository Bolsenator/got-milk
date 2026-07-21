extends CanvasLayer

@onready var level_up_ui: Control = $LevelUp
@onready var game_over_ui: Control = $GameOver
@onready var level_complete_ui: Control = $LevelComplete
@onready var pause_ui: Control = $Pause
@onready var hud_ui: Control = $HUD

func show_level_up_ui() -> void:
	level_up_ui.show()
	
func hide_level_up_ui() -> void:
	level_up_ui.hide()

func show_game_over_ui() -> void:
	game_over_ui.show()
	
func hide_game_over_ui() -> void:
	game_over_ui.hide()

func show_level_complete_ui() -> void:
	level_complete_ui.show()

func hide_level_complete_ui() -> void:
	level_complete_ui.hide()

func toggle_pause_ui() -> void:
	pause_ui.visible = !pause_ui.visible
