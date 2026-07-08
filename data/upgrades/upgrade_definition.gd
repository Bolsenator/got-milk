class_name UpgradeDefinition
extends Resource

enum Target { PLAYER, MINION, SUMMON_MINION }

@export var upgrade_name: String
@export_multiline var description: String
@export var target: Target
@export var stat: String	# property name to modify on the target
@export var bonus: float
@export var max_count: int = 1
@export var icon: Texture2D
