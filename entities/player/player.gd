extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $TextureProgressBar
@onready var level = $".."

@onready var heal_sound = $HealSound
@onready var take_damage_sound = $TakeDamageSound
@onready var level_up_sound = $LevelUpSound
@onready var died_sound = $DiedSound

signal exp_changed(new_exp, max_exp)
signal level_up()
signal player_died()

var speed : int = 400
var rotation_speed : float = 1.5
var current_health = 100 :
	set(new_value):
		current_health = clamp (new_value, 0, max_health)
		health_bar.value = current_health
var max_health = 100
var current_exp : float = 0.0 :
	set(new_value):
		current_exp = new_value
		exp_changed.emit(current_exp, max_exp)
var max_exp : float = 100.0

func _ready():
	animated_sprite.play("idle")
	health_bar.max_value = max_health
	health_bar.min_value = 0
	health_bar.value = current_health

func _physics_process(delta: float):
	var direction = Input.get_vector("left","right","up","down")
	velocity = direction * speed
	move_and_slide()
	
	if direction.x !=0:
		animated_sprite.flip_h = direction.x < 0

func collect_exp_item():
	gain_exp(max_exp)

func gain_exp(exp_gain : float):
	current_exp += exp_gain

	while current_exp >= max_exp:
		level_up_sound.play()
		level_up.emit()
		await level.level_up_reward_chosen
		current_exp -= max_exp

func heal(amount: int):
	current_health += amount
	heal_sound.play()

func take_damage(damage):
	current_health -= damage
	take_damage_sound.play()
	if current_health <= 0:
		die()

func die():
	died_sound.play()
	player_died.emit()
