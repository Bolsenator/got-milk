extends Control

var upgrade_count: int = 0
@onready var label = $Label

func increment(value: int):
	upgrade_count += value
	label.text = "x" + str(upgrade_count)
