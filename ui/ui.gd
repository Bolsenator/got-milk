extends CanvasLayer

@onready var level_up_ui = $LevelUp
@onready var game_over_ui = $GameOver

func show_level_up_ui():
	level_up_ui.show()
	
func hide_level_up_ui():
	level_up_ui.hide()

func show_game_over_ui():
	game_over_ui.show()
	
func hide_game_over_ui():
	game_over_ui.hide()
