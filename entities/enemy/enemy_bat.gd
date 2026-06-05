class_name EnemyBat
extends EnemyBase

func _ready():
	speed = 200.0
	max_health = 5.0
	damage = 5.0
	exp_reward = 10
	super._ready()
