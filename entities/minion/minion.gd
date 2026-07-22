extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var aggro_range: Area2D = $AggroRange
@onready var hitbox: Area2D = $Hitbox
@onready var minion_to_minion_hitbox: Area2D = $MinionToMinionHitbox

@onready var attack_sound: AudioStreamPlayer = $AttackSound
@onready var summon_sound: AudioStreamPlayer = $SummonSound

@onready var attack_cooldown_bar: TextureProgressBar = $AttackCooldownBar
@onready var attack_cooldown_bar_animation: AnimationPlayer = $AttackCooldownBar/AnimationPlayer

var player: CharacterBody2D
var target_enemy: CharacterBody2D = null

var current_target_position: Vector2
var max_distance_squared_to_target: float = 256.0 # Squared in advance for distance_to calculations

var stats: StatBlock = StatBlock.new()

var damage: float
var attack_cooldown: float
var minion_movement_speed: float
var crit_chance: float
var crit_damage: float
var multi_attack: float

var soft_leash_radius: float = 300.0
var hard_leash_radius: float = 800.0
var deceleration: float = 2.0
var minion_to_minion_repulsion_speed: float = 25.0
var attack_cushion: float = 16 # Prevents sprite from going crazy when right on enemy
var cooldown_timer: float = 0.0
var is_on_cooldown: bool = false
var enemy_in_range: bool = false # Range for attack to proc
var target_enemy_distance_to_player: float
var player_distance: float

enum State { ATTACK, FOLLOW }
var state: State = State.FOLLOW

signal crit_landed(enemy_position: Vector2)

func _ready() -> void:
	_register_stats()
	stats.stat_changed.connect(_on_stat_changed)
	
	animated_sprite.play("idle")
	player = get_tree().get_first_node_in_group("player")
	summon_sound.play(2.0)
	
	# Wait for navigation map to be ready
	await get_tree().physics_frame
	
	# Setup initial navigation
	navigation_agent.max_speed = minion_movement_speed
	current_target_position = player.global_position
	navigation_agent.target_position = current_target_position
	
	# Setup cooldown bar
	attack_cooldown_bar.self_modulate.a = 0.0

func _physics_process(delta: float) -> void:
	# Handle attack cooldown
	cooldown_timer -= delta
	if is_on_cooldown:
		attack_cooldown_bar.value = cooldown_timer
		if cooldown_timer <= 0.0:
			fade_out_attack_cooldown_bar()
			is_on_cooldown = false
	
	# Update to stay within hard leash radius
	player_distance = global_position.distance_to(player.global_position)
	
	# Find nearest enemy within range
	if target_enemy == null:
		acquire_target()
	
	# Set state
	set_targeting_state()
	
	# Act on state
	match state:
		State.ATTACK:
			if enemy_in_range and !is_on_cooldown:
				for attack: int in multi_attack:
					await attack_enemy()
			else:
				set_target_position(target_enemy, attack_cushion)
		State.FOLLOW:
			set_target_position(player, soft_leash_radius)
	
	# Add minion to minion nudge to prevent grouping
	for area: Area2D in minion_to_minion_hitbox.get_overlapping_areas():
		if area.is_in_group("minion_to_minion_hitbox"):
			var direction: Vector2 = (global_position - area.global_position).normalized()
			velocity += direction * minion_to_minion_repulsion_speed
	
	move_and_slide()
	animated_sprite.flip_h = velocity.x < 0

func _register_stats() -> void:
	# modifier constructor format: (name: String, start: float, m: Mode = Mode.MULTIPLY, initial_modifier: float = 1.0)
	# This is using magic numbers. Might be worth moving to global script vars for easier modifying
	_register(StatModifier.new(UpgradeDefinition.Stat.DAMAGE, 5.0))
	_register(StatModifier.new(UpgradeDefinition.Stat.ATTACK_COOLDOWN, 2.0))
	_register(StatModifier.new(UpgradeDefinition.Stat.MINION_MOVEMENT_SPEED, 325.0))
	_register(StatModifier.new(UpgradeDefinition.Stat.CRIT_CHANCE, 1.0, StatModifier.Mode.MULTIPLY, 0.0))
	_register(StatModifier.new(UpgradeDefinition.Stat.CRIT_DAMAGE, 1.0, StatModifier.Mode.MULTIPLY, 1.5))
	_register(StatModifier.new(UpgradeDefinition.Stat.MULTI_ATTACK, 1.0, StatModifier.Mode.ADD, 0.0))

func _register(modifier: StatModifier) -> void:
	stats.register(modifier)
	_on_stat_changed(modifier.stat, modifier.value)

func set_target_position(target: CharacterBody2D, target_desired_distance: float) -> void:
	navigation_agent.target_desired_distance = target_desired_distance
	if current_target_position.distance_squared_to(target.global_position) > max_distance_squared_to_target:
		current_target_position = target.global_position 
		navigation_agent.target_position = current_target_position
	var current_agent_position: Vector2 = global_position
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var new_velocity: Vector2 = current_agent_position.direction_to(next_path_position) * minion_movement_speed
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(new_velocity)

func acquire_target() -> void:
	var closest: CharacterBody2D = null
	var closest_distance: float = INF
	
	for body: PhysicsBody2D in aggro_range.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			var distance: float = global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest = body
				closest_distance = distance
	
	if closest:
		target_enemy = closest
		if !target_enemy.tree_exited.is_connected(_on_target_died):
			target_enemy.tree_exited.connect(_on_target_died)

func set_targeting_state() -> void:
	# Outside of leash distance
	if player_distance > hard_leash_radius:
		target_enemy = null
		state = State.FOLLOW
		return
	
	# No nearby enemies
	if target_enemy == null:
		state = State.FOLLOW
		return
	
	# Within leash and nearby enemies
	enemy_in_range = target_enemy in hitbox.get_overlapping_bodies()
	target_enemy_distance_to_player = player.global_position.distance_to(target_enemy.global_position)
	if target_enemy_distance_to_player < hard_leash_radius:
		state = State.ATTACK
	else:
		state = State.FOLLOW

func attack_enemy() -> void:
	for body: PhysicsBody2D in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			var final_damage: float = damage
			if randf() < crit_chance:
				final_damage = damage * crit_damage
				crit_landed.emit(body.global_position)
			body.take_damage(final_damage)
	cooldown_timer = attack_cooldown
	is_on_cooldown = true
	pop_in_attack_cooldown_bar()
	attack_sound.play()
	animated_sprite.play("attack")
	await animated_sprite.animation_finished

func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	stats.apply_upgrade(upgrade)

func pop_in_attack_cooldown_bar() -> void:
	attack_cooldown_bar_animation.play("pop_in")

func fade_out_attack_cooldown_bar() -> void:
	attack_cooldown_bar_animation.play("fade_out")

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

func _on_aggro_range_body_exited(body: Node2D) -> void:
	if body == target_enemy:
		target_enemy = null

func _on_target_died() -> void:
	enemy_in_range = false
	target_enemy = null
	acquire_target()

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack":
		animated_sprite.play("idle")

func _on_stat_changed(_stat: UpgradeDefinition.Stat, new_value: float) -> void:
	match _stat:
		UpgradeDefinition.Stat.DAMAGE:
			damage = new_value
		UpgradeDefinition.Stat.ATTACK_COOLDOWN:
			attack_cooldown = new_value
			attack_cooldown_bar.max_value = attack_cooldown
		UpgradeDefinition.Stat.MINION_MOVEMENT_SPEED:
			minion_movement_speed = new_value
		UpgradeDefinition.Stat.CRIT_CHANCE:
			crit_chance = new_value
		UpgradeDefinition.Stat.CRIT_DAMAGE:
			crit_damage = new_value
		UpgradeDefinition.Stat.MULTI_ATTACK:
			multi_attack = new_value
