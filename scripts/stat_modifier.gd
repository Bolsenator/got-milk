class_name StatModifier
extends RefCounted

enum Mode { MULTIPLY, ADD }

var stat: UpgradeDefinition.Stat
var start_value: float
var mode: Mode
var modifier: float
var value: float:
	get: return start_value * modifier if mode == Mode.MULTIPLY else start_value + modifier

func _init(_stat: UpgradeDefinition.Stat, start: float, m: Mode = Mode.MULTIPLY, initial_modifier: float = 1.0) -> void:
	stat = _stat
	start_value = start
	mode = m
	modifier = initial_modifier

func apply_bonus(bonus: float) -> float:
	modifier += bonus
	return value
