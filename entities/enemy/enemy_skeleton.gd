class_name EnemySkeleton
extends EnemyBase

func _ready():
	speed = 120.0
	max_health = 50.0
	damage = 15.0
	exp_reward = 10
	super._ready()
