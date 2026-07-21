class_name UpgradeItem
extends Area2D

var upgrade_stat_name: String = ""

signal create_offscreen_indicator(upgrade_item: Area2D)
signal apply_upgrade_item(upgrade_stat_name: String)

func _ready() -> void:
	create_offscreen_indicator.emit(self) # This only runs on items created during the game. For those at the start, the level calls _on_level_ready in this script to run it after the level is ready.

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		apply_upgrade_item.emit(upgrade_stat_name)
		queue_free()

func _on_level_ready() -> void:
	create_offscreen_indicator.emit(self) 
