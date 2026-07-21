class_name EnemySlime
extends EnemyBase

func _ready() -> void:
	speed = 50.0
	max_health = 5.0
	damage = 5.0
	exp_reward = 5
	super._ready()
