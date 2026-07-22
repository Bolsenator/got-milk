class_name UpgradeDefinition
extends Resource

enum Target { PLAYER, MINION, SUMMON_MINION }

enum Stat { 
	DAMAGE_REDUCTION = 0,
	EXP_GAIN = 1,
	HEALTH_REGEN = 2,
	MAX_HEALTH = 3,
	PLAYER_MOVEMENT_SPEED = 4,
	
	ATTACK_COOLDOWN = 5,
	CRIT_CHANCE = 6,
	CRIT_DAMAGE = 7,
	DAMAGE = 8,
	MINION_MOVEMENT_SPEED = 9,
	MULTI_ATTACK = 10,
	
	SUMMON_MINION = 11,
}

@export var upgrade_name: String # Flavor stat name
@export_multiline var description: String
@export var target: Target
@export var stat: Stat # Informative stat name used in entity's script
@export var bonus: float
@export var max_count: int = 1
@export var icon: Texture2D
