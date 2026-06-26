extends Control

var heal_amount: int = 50

signal summon_minion()
signal heal_player(heal_amount: int)

func _on_summon_minion_pressed() -> void:
	summon_minion.emit()

func _on_heal_player_pressed() -> void:
	heal_player.emit(heal_amount)
