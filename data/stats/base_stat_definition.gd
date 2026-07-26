# Static base stat which defines the starting value for an entities stat within a stat block

class_name BaseStatDefinition
extends Resource

@export var stat: StatId.Stat
@export var initial_value: float = 1.0
@export var mode: StatId.Mode = StatId.Mode.MULTIPLY
@export var initial_modifier: float = 1.0
