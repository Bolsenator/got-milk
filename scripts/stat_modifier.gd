class_name StatModifier
extends RefCounted

var stat: StatId.Stat
var start_value: float
var mode: StatId.Mode
var modifier: float
var value: float:
	get: return start_value * modifier if mode == StatId.Mode.MULTIPLY else start_value + modifier

func _init(_stat: StatId.Stat, start: float, m: StatId.Mode = StatId.Mode.MULTIPLY, initial_modifier: float = 1.0) -> void:
	stat = _stat
	start_value = start
	mode = m
	modifier = initial_modifier

func apply_bonus(bonus: float) -> float:
	modifier += bonus
	return value
