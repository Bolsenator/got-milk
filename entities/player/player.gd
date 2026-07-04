extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $TextureProgressBar
@onready var level = $".."

@onready var heal_sound = $HealSound
@onready var take_damage_sound = $TakeDamageSound
@onready var level_up_sound = $LevelUpSound
@onready var died_sound = $DiedSound
@onready var health_regen_timer = $HealthRegenTimer

signal exp_changed(new_exp, max_exp)
signal level_up()
signal player_died()

#############################################
# Player Upgradable Stats
#############################################

# Health
var max_health_start: float = 100.00
var max_health_modifier: float = 1.00 :
	set(new_value):
		max_health_modifier = new_value
		max_health = max_health_start * max_health_modifier
		health_bar.max_value = max_health
var max_health: float = max_health_start * max_health_modifier

# Regen Per Second
var health_regen_per_sec_start: float = 1.00
var health_regen_per_sec_modifier: float = 0.00 :
	set(new_value):
		health_regen_per_sec_modifier = new_value
		health_regen_per_sec = health_regen_per_sec_start * health_regen_per_sec_modifier
var health_regen_per_sec: float = health_regen_per_sec_start * health_regen_per_sec_modifier

# Damage Reduction
var damage_reduction_start: float = 1.00
var damage_reduction_modifier: float = 0.00 :
	set(new_value):
		damage_reduction_modifier = new_value
		damage_reduction = damage_reduction_start * damage_reduction_modifier
var damage_reduction: float = damage_reduction_start * damage_reduction_modifier

# Movement Speed
var player_movement_speed_start : float = 300.00
var player_movement_speed_modifier: float = 1.00 :
	set(new_value):
		player_movement_speed_modifier = new_value
		player_movement_speed = player_movement_speed_start * player_movement_speed_modifier
var player_movement_speed : float = player_movement_speed_start * player_movement_speed_modifier

# Exp Gain
var exp_gain_start: float = 1.00
var exp_gain_modifier: float = 1.00 : 
	set(new_value):
		exp_gain_modifier = new_value
		exp_gain = exp_gain_start * exp_gain_modifier
var exp_gain: float = exp_gain_start * exp_gain_modifier

#############################################

var health_regen_cooldown_sec = 1.0
var rotation_speed : float = 1.5
var current_health = 100 :
	set(new_value):
		current_health = clamp (new_value, 0, max_health)
		health_bar.value = current_health
var current_exp : float = 0.0 :
	set(new_value):
		current_exp = new_value
		exp_changed.emit(current_exp, max_exp)
var max_exp : float = 30.0
var player_level: int = 1
var flash_tween: Tween

#############################################

func _ready():
	animated_sprite.play("idle")
	health_bar.max_value = max_health
	health_bar.min_value = 0
	health_bar.value = current_health
	health_regen_timer.start(health_regen_cooldown_sec)

func _physics_process(_delta: float):
	var direction = Input.get_vector("left","right","up","down")
	velocity = direction * player_movement_speed
	move_and_slide()
	
	if direction.x !=0:
		animated_sprite.flip_h = direction.x < 0

func collect_exp_item():
	gain_exp(max_exp)

func gain_exp(exp_amount : float):
	current_exp += exp_amount * exp_gain

	while current_exp >= max_exp:
		player_level += 1
		level_up_sound.play()
		level_up.emit(player_level)
		await level.level_up_reward_chosen
		current_exp -= max_exp

func apply_upgrade(upgrade):
	var new_modifier = get(upgrade["stat"]) + upgrade["bonus"]
	set(upgrade["stat"], new_modifier)

func heal(amount: int):
	current_health += amount
	heal_sound.play()

func take_damage(damage) -> void:
	current_health -= damage * (1.00 - damage_reduction)
	take_damage_sound.play()
	flash_damage()
	if current_health <= 0:
		die()

func flash_damage() -> void:
	if flash_tween:
		flash_tween.kill()
	
	flash_tween = create_tween()
	flash_tween.tween_property(animated_sprite, "modulate", Color("cf0a0a"), 0.03)
	flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)

func die():
	died_sound.play()
	player_died.emit()


func _on_health_regen_timer_timeout() -> void:
	current_health += health_regen_per_sec * max_health
