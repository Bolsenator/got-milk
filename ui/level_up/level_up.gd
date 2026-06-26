extends Control

var heal_amount: int = 50

@onready var upgrade_buttons = $NinePatchRect/MarginContainer/UpgradeButtons

signal apply_upgrade(upgrade)

func populate_upgrade_buttons(upgrades: Array):
	for button in upgrade_buttons.get_children():
		var upgrade = upgrades.pop_back()
		if button.pressed.is_connected(_on_upgrade_selected):
			button.pressed.disconnect(_on_upgrade_selected)
		button.pressed.connect(_on_upgrade_selected.bind(upgrade))
		button.text = upgrade["name"]

func _on_upgrade_selected(upgrade: Dictionary):
	apply_upgrade.emit(upgrade)
