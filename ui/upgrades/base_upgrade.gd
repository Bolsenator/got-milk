extends Control

@onready var label = $Label

func update_display(upgrade: Dictionary):
	# Update label
	label.text = "x" + str(upgrade["count"]) + "/" + str(upgrade["max"])
	
	# Update tooltip if applicable for the stat
	if upgrade["target"] != "summon_minion":
		var bonus_percent: float = upgrade["bonus"] * upgrade["count"] * 100.0
		tooltip_text = "%s: %+.f%%" % [upgrade["name"], bonus_percent]
