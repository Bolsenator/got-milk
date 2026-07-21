class_name EnemyDevil
extends EnemyBase

func _ready() -> void:
	speed = 150.0
	max_health = 2000.0
	damage = 80.0
	exp_reward = 1000
	super._ready()
