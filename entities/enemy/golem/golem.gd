class_name EnemyGolem
extends EnemyBase

func _ready() -> void:
	speed = 50.0
	max_health = 400.0
	damage = 20.0
	exp_reward = 25
	super._ready()
