class_name EnemyBeholder
extends EnemyBase

func _ready():
	speed = 150.0
	max_health = 300.0
	damage = 40.0
	exp_reward = 40
	super._ready()
