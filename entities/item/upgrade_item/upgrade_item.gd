class_name UpgradeItem
extends Area2D

var upgrade_stat_name: String = ""

signal apply_upgrade_item(upgrade_stat_name: String)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		apply_upgrade_item.emit(upgrade_stat_name)
		queue_free()
