class_name EnemySnake
extends EnemyBase

func _ready():
	speed = 60.0
	max_health = 7.5
	damage = 10.0
	exp_reward = 10
	super._ready()
