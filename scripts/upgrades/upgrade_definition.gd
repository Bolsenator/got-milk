class_name UpgradeDefinition
extends Resource

enum Target { PLAYER, MINION, SUMMON_MINION }

@export var upgrade_name: String # Flavor stat name
@export_multiline var description: String
@export var target: Target
@export var stat: StatId.Stat # Informative stat name enum used in entity's script
@export var bonus: float
@export var max_count: int = 1
@export var icon: Texture2D
