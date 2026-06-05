class_name EnemyGolem
extends EnemyBase

func _ready():
	speed = 100.0
	max_health = 200.0
	damage = 20.0
	exp_reward = 20
	super._ready()
