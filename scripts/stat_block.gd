class_name StatBlock
extends RefCounted

var _modifiers: Dictionary = {} # stat_name -> StatModifier
signal stat_changed(stat: String, new_value: float)

func register(modifier: StatModifier) -> void:
	_modifiers[modifier.stat] = modifier

func get_value(_stat: UpgradeDefinition.Stat) -> float:
	return _modifiers[_stat].value

func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	var new_value: float = _modifiers[upgrade.stat].apply_bonus(upgrade.bonus)
	stat_changed.emit(upgrade.stat, new_value)
