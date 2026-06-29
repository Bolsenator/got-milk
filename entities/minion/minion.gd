extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var navigation_agent = $NavigationAgent2D
@onready var aggro_range = $AggroRange
@onready var hitbox = $Hitbox
@onready var minion_to_minion_hitbox = $MinionToMinionHitbox

@onready var attack_sound = $AttackSound
@onready var summon_sound = $SummonSound

#############################################
# Minion Upgradable Stats
#############################################

# Damage
var damage_start: float = 5.0
var damage_modifier: float = 1.0 : 
	set(new_value):
		damage_modifier = new_value
		damage = damage_start * damage_modifier
var damage: float = damage_start * damage_modifier

# Attack Speed
var attack_cooldown_start: float = 1.0
var attack_cooldown_modifier: float = 1.0 : 
	set(new_value):
		attack_cooldown_modifier = new_value
		attack_cooldown = attack_cooldown_start * attack_cooldown_modifier
var attack_cooldown: float = attack_cooldown_start * attack_cooldown_modifier

# Movement Speed
var minion_movement_speed_start: float = 325.0
var minion_movement_speed_modifier: float = 1.0 : 
	set(new_value):
		minion_movement_speed_modifier = new_value
		minion_movement_speed = minion_movement_speed_start * minion_movement_speed_modifier
var minion_movement_speed: float = minion_movement_speed_start * minion_movement_speed_modifier

# Crit Chance
var crit_chance_start: float = 1.0
var crit_chance_modifier: float = 0.0 : 
	set(new_value):
		crit_chance_modifier = new_value
		crit_chance = crit_chance_start * crit_chance_modifier
var crit_chance = crit_chance_start * crit_chance_modifier

# Crit Damage
var crit_damage_start: float = 1.0
var crit_damage_modifier: float = 1.5 : 
	set(new_value):
		crit_damage_modifier = new_value
		crit_damage = crit_damage_start * crit_damage_modifier
var crit_damage = crit_damage_start * crit_damage_modifier

#############################################

var player: CharacterBody2D
var target_enemy: CharacterBody2D = null

var current_target_position: Vector2
var max_distance_squared_to_target: float = 256.0 # Squared in advance for distance_to calculations


var soft_leash_radius = 300.0
var hard_leash_radius = 900.0
var deceleration = 2.0
var minion_to_minion_repulsion_speed = 25.0
var attack_cushion: float = 16 # Prevents sprite from going crazy when right on enemy
var cooldown_timer: float = 0.0
var enemy_in_range: bool = false # Range for attack to proc
var target_enemy_distance: float
var player_distance: float

enum State { ATTACK, FOLLOW }
var state = State.FOLLOW

func _ready():
	animated_sprite.play("idle")
	player = get_tree().get_first_node_in_group("player")
	summon_sound.play(2.0)
	navigation_agent.max_speed = minion_movement_speed
	# Wait for navigation map to be ready
	await get_tree().physics_frame
	current_target_position = player.global_position
	navigation_agent.target_position = current_target_position
	

func _physics_process(delta: float):
	cooldown_timer -= delta
	if player == null:
		return
	
	# Keep within hard leash distance
	player_distance = global_position.distance_to(player.global_position)
	if player_distance > hard_leash_radius:
		target_enemy = null
		state = State.FOLLOW
	
	# Find nearest enemy within range
	if target_enemy == null:
		acquire_target()
	
	set_targeting_state()
	
	# Act on state
	match state:
		State.ATTACK:
			if enemy_in_range and cooldown_timer <= 0.0:
				attack_enemy()
			else:
				set_target_position(target_enemy, attack_cushion)
		State.FOLLOW:
			set_target_position(player, soft_leash_radius)
	
	# Add minion to minion nudge to prevent grouping
	for area in minion_to_minion_hitbox.get_overlapping_areas():
		if area.is_in_group("minion_to_minion_hitbox"):
			var direction = (global_position - area.global_position).normalized()
			velocity += direction * minion_to_minion_repulsion_speed
	
	move_and_slide()
	animated_sprite.flip_h = velocity.x < 0

func set_target_position(target: CharacterBody2D, target_desired_distance: float):
	navigation_agent.target_desired_distance = target_desired_distance
	if current_target_position.distance_squared_to(target.global_position) > max_distance_squared_to_target:
		current_target_position = target.global_position 
		navigation_agent.target_position = current_target_position
	var current_agent_position = global_position
	var next_path_position = navigation_agent.get_next_path_position()
	var new_velocity = current_agent_position.direction_to(next_path_position) * minion_movement_speed
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(new_velocity)

func acquire_target() -> void:
	var closest: CharacterBody2D = null
	var closest_distance: float = INF
	
	for body in aggro_range.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			var distance = global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest = body
				closest_distance = distance
	
	if closest:
		target_enemy = closest
		if !target_enemy.tree_exited.is_connected(_on_target_died):
			target_enemy.tree_exited.connect(_on_target_died)

func set_targeting_state() -> void:
	if target_enemy == null:
		state = State.FOLLOW
	else:
		enemy_in_range = target_enemy in hitbox.get_overlapping_bodies()
		target_enemy_distance = global_position.distance_to(target_enemy.global_position)
		if target_enemy_distance < hard_leash_radius:
			state = State.ATTACK
		else:
			state = State.FOLLOW

func attack_enemy():
	var final_damage: float = damage
	randomize()
	if randf() < crit_chance:
		final_damage = damage * crit_damage
	target_enemy.take_damage(final_damage)
	cooldown_timer = attack_cooldown
	attack_sound.play()

func apply_upgrade(upgrade):
	var new_modifier = get(upgrade["stat"]) + upgrade["bonus"]
	set(upgrade["stat"], new_modifier)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

func _on_aggro_range_body_exited(body: Node2D):
	if body == target_enemy:
		target_enemy = null

func _on_target_died():
	enemy_in_range = false
	target_enemy = null
	acquire_target()
