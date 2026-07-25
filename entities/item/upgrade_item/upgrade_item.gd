class_name UpgradeItem
extends Area2D

@export var upgrade: UpgradeDefinition

@onready var sprite: Sprite2D = $Sprite2D

signal create_offscreen_indicator(upgrade_item: Area2D)
signal apply_upgrade_item(upgrade: UpgradeDefinition)

func _ready() -> void:
	sprite.texture = upgrade.icon
	create_offscreen_indicator.emit(self) # This only runs on items created during the game. For those at the start, the level calls _on_level_ready in this script to run it after the level is ready.

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		apply_upgrade_item.emit(upgrade)
		queue_free()

func level_ready() -> void:
	create_offscreen_indicator.emit(self)
