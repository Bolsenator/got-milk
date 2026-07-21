extends Control

@onready var upgrade_buttons: VBoxContainer = $NinePatchRect/MarginContainer/UpgradeButtons

signal apply_upgrade(upgrade: UpgradeDefinition)

func populate_upgrade_buttons(upgrades: Array) -> void:
	for button: Button in upgrade_buttons.get_children():
		var upgrade: UpgradeDefinition = upgrades.pop_back()
		if button.pressed.is_connected(_on_upgrade_selected):
			button.pressed.disconnect(_on_upgrade_selected)
		button.pressed.connect(_on_upgrade_selected.bind(upgrade))
		button.icon = upgrade.icon
		button.text = upgrade.upgrade_name
		button.tooltip_text = upgrade.description

func _on_upgrade_selected(upgrade: UpgradeDefinition) -> void:
	apply_upgrade.emit(upgrade)
