extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $TextureProgressBar
@onready var level = $"../.."

@onready var heal_sound = $HealSound
@onready var take_damage_sound = $TakeDamageSound
@onready var level_up_sound = $LevelUpSound
@onready var died_sound = $DiedSound
@onready var health_regen_timer = $HealthRegenTimer

signal exp_changed(new_exp, max_exp)
signal level_up()
signal player_died()

var stats:= StatBlock.new()

var max_health
var health_regen_per_sec
var damage_reduction
var player_movement_speed
var exp_gain

var health_regen_cooldown_sec = 1.0
var rotation_speed : float = 1.5
var current_health = 100.0 :
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

func _ready():
	_register_stats()
	stats.stat_changed.connect(_on_stat_changed)
	
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

func _register_stats() -> void:
	# modifier constructor format: (name: String, start: float, m: Mode = Mode.MULTIPLY, initial_modifier: float = 1.0)
	_register(StatModifier.new("max_health_modifier", 100.0))
	_register(StatModifier.new("health_regen_per_sec_modifier", 1.0))
	_register(StatModifier.new("damage_reduction_modifier", 1.0, StatModifier.Mode.MULTIPLY, 0.0))
	_register(StatModifier.new("player_movement_speed_modifier", 300.0))
	_register(StatModifier.new("exp_gain_modifier", 1.0))

func _register(modifier: StatModifier) -> void:
	stats.register(modifier)
	_on_stat_changed(modifier.stat_name, modifier.value)

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
	stats.apply_upgrade(upgrade)

func heal(amount: float):
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

func _on_stat_changed(stat_name: String, new_value: float):
	match stat_name:
		"max_health_modifier":
			max_health = new_value
			health_bar.max_value = max_health
		"health_regen_per_sec_modifier":
			health_regen_per_sec = new_value
		"damage_reduction_modifier":
			damage_reduction = new_value
		"player_movement_speed_modifier":
			player_movement_speed = new_value
		"exp_gain_modifier":
			exp_gain = new_value
