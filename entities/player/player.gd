extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var level: Node = $"../.."

@onready var heal_sound: AudioStreamPlayer = $HealSound
@onready var take_damage_sound: AudioStreamPlayer = $TakeDamageSound
@onready var level_up_sound: AudioStreamPlayer = $LevelUpSound
@onready var died_sound: AudioStreamPlayer = $DiedSound
@onready var health_regen_timer: Timer = $HealthRegenTimer
@onready var invulnerability_phase_timer: Timer = $InvulnerabilityPhaseTimer

signal exp_changed(new_exp: float, max_exp: float)
signal level_up()
signal player_died()

var stats: StatBlock = StatBlock.new()

var player_movement_speed: float

var current_health: float = 100.0 :
	set(new_value):
		current_health = clamp (new_value, 0, stats.get_value(StatId.Stat.MAX_HEALTH))
		health_bar.value = current_health
var current_exp : float = 0.0 :
	set(new_value):
		current_exp = new_value
		exp_changed.emit(current_exp, max_exp)
var max_exp : float = 30.0
var player_level: int = 1
var flash_tween: Tween
var _is_invulnerable: bool = false

func _ready() -> void:
	_register_stats()
	stats.stat_changed.connect(_on_stat_changed)
	
	animated_sprite.play("idle")
	health_bar.max_value = stats.get_value(StatId.Stat.MAX_HEALTH)
	health_bar.min_value = 0
	current_health = stats.get_value(StatId.Stat.MAX_HEALTH)
	health_bar.value = current_health
	health_regen_timer.start()

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("left","right","up","down")
	velocity = direction * player_movement_speed
	move_and_slide()
	
	if direction.x !=0:
		animated_sprite.flip_h = direction.x < 0

func _register_stats() -> void:
	# modifier constructor format: (name: String, start: float, m: Mode = Mode.MULTIPLY, initial_modifier: float = 1.0)
	_register(StatModifier.new(StatId.Stat.MAX_HEALTH, 100.0))
	_register(StatModifier.new(StatId.Stat.HEALTH_REGEN, 1.0, StatModifier.Mode.MULTIPLY, 0.0))
	_register(StatModifier.new(StatId.Stat.DAMAGE_REDUCTION, 1.0, StatModifier.Mode.MULTIPLY, 0.0))
	_register(StatModifier.new(StatId.Stat.PLAYER_MOVEMENT_SPEED, 300.0))
	_register(StatModifier.new(StatId.Stat.EXP_GAIN, 1.0))

func _register(modifier: StatModifier) -> void:
	stats.register(modifier)
	_on_stat_changed(modifier.stat, modifier.value)

func collect_exp_item() -> void:
	gain_exp(max_exp)

func gain_exp(exp_amount : float) -> void:
	current_exp += exp_amount * stats.get_value(StatId.Stat.EXP_GAIN)

	while current_exp >= max_exp:
		player_level += 1
		level_up_sound.play()
		level_up.emit(player_level)
		await level.level_up_reward_chosen
		current_exp -= max_exp

func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	stats.apply_upgrade(upgrade)

func heal(amount: float) -> void:
	current_health += amount
	heal_sound.play()

func take_damage(damage: float) -> void:
	# Handle invulnerability phase
	if _is_invulnerable:
		return
	_is_invulnerable = true
	invulnerability_phase_timer.start()
	
	# Deal damage
	current_health -= damage * (1.00 - stats.get_value(StatId.Stat.DAMAGE_REDUCTION))
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

func die() -> void:
	died_sound.play()
	player_died.emit()

func _on_health_regen_timer_timeout() -> void:
	current_health += stats.get_value(StatId.Stat.HEALTH_REGEN) * stats.get_value(StatId.Stat.MAX_HEALTH)

func _on_invulnerability_phase_timer_timeout() -> void:
	_is_invulnerable = false

func _on_stat_changed(_stat: StatId.Stat, new_value: float) -> void:
	# Only updates things which require to be updated, not every stat
	match _stat:
		StatId.Stat.MAX_HEALTH:
			# Update health bar UI
			health_bar.max_value = stats.get_value(StatId.Stat.MAX_HEALTH)
		StatId.Stat.PLAYER_MOVEMENT_SPEED:
			# Movement speed requires a locally cached var because it is called every physics frame
			player_movement_speed = new_value
