class_name EnemyDemon
extends EnemyBase

func _ready():
	speed = 100.0
	max_health = 100.0
	damage = 25.0
	exp_reward = 20
	super._ready()
