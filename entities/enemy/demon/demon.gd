class_name EnemyDemon
extends EnemyBase

func _ready() -> void:
	speed = 100.0
	max_health = 100.0
	damage = 25.0
	exp_reward = 25
	super._ready()
