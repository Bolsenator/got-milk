extends Control

var upgrade_count: int = 0
@onready var label = $Label

func increment(value: int):
	upgrade_count += value
	label.text = "x" + str(upgrade_count)

func update_tooltip(upgrade: Dictionary):
	var description: String = upgrade["name"]
	var bonus_percent: float = upgrade["bonus"] * upgrade_count * 100.0
	tooltip_text = "%s: %+.f%%" % [description, bonus_percent]
