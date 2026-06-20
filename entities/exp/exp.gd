extends Area2D

var exp_value: float = 0
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	animated_sprite.play("default")

func initialize(value: float = 0, spawn_position: Vector2 = Vector2(0,0)):
	exp_value = value
	global_position = spawn_position

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.gain_exp(exp_value)
		queue_free()
