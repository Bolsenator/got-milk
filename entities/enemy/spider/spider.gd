class_name EnemySpider
extends EnemyBase

func _ready():
	speed = 120.0
	max_health = 30.0
	damage = 10.0
	exp_reward = 10
	super._ready()
