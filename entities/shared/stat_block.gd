class_name StatBlock
extends RefCounted

var _modifiers: Dictionary = {} # stat_name -> StatModifier
signal stat_changed(stat_name: String, new_value: float)

func register(modifier: StatModifier) -> void:
	_modifiers[modifier.stat_name] = modifier

func get_value(stat_name: String) -> float:
	return _modifiers[stat_name].value

func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	var new_value: float = _modifiers[upgrade.stat].apply_bonus(upgrade.bonus)
	stat_changed.emit(upgrade.stat, new_value)
