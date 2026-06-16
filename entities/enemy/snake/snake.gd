class_name EnemySnake
extends EnemyBase

func _ready():
	speed = 120.0
	max_health = 10.0
	damage = 10.0
	exp_reward = 10
	super._ready()
