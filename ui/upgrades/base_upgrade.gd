extends Control

@onready var label = $Label

func update_display(upgrade: UpgradeDefinition, count: int):
	# Update label
	label.text = "x" + str(count) + "/" + str(upgrade.max_count)
	
	# Update tooltip if applicable for the stat
	if upgrade.target != UpgradeDefinition.Target.SUMMON_MINION:
		var bonus_percent: float = upgrade.bonus * count * 100.0
		tooltip_text = "%s: %+.f%%" % [upgrade.upgrade_name, bonus_percent]
