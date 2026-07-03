class_name EnemyBase
extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var navigation_agent = $NavigationAgent2D
@onready var on_screen_notifier = $VisibleOnScreenNotifier2D

signal died(exp: int, position: Vector2)

var spawn_time_ms: int
var max_health: float = 5.0
var health: float
var speed: float = 50.0
var damage: float = 5.0
var exp_reward: int = 5
#var attack_cushion: float = 4 # Prevents sprite from going crazy when right on player
var player_in_range: bool = false
var attack_cooldown: float = 1.0
var cooldown_timer: float = 0.0

var current_target_position: Vector2
var max_distance_squared_to_player: float = 4096.0 # Squared in advance for distance_to calculations

var player: CharacterBody2D

func _ready():
	spawn_time_ms = Time.get_ticks_msec()
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	animated_sprite.play("idle")
	navigation_agent.max_speed = speed
	# Wait for navigation map to be ready
	await get_tree().physics_frame
	set_target_position()
	
func _physics_process(delta: float):
	cooldown_timer -= delta
	if player == null:
		return
	
	# Attack player
	if player_in_range and cooldown_timer <= 0.0:
		player.take_damage(damage)
		cooldown_timer = attack_cooldown
	
	# Chase player
	if has_target_moved_past_threshold():
		set_target_position()
	
	move_and_slide()
	animated_sprite.flip_h = velocity.x < 0

func set_target_position():
	current_target_position = player.global_position 
	navigation_agent.target_position = current_target_position
	var current_agent_position = global_position
	var next_path_position = navigation_agent.get_next_path_position()
	var new_velocity = current_agent_position.direction_to(next_path_position) * speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(new_velocity)

func has_target_moved_past_threshold():
	return current_target_position.distance_squared_to(player.global_position) > max_distance_squared_to_player

func take_damage(amount: float):
	health -= amount
	if health <= 0:
		die()

func die():
	died.emit(exp_reward,global_position)
	queue_free()

func _on_area_2d_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = true

func _on_area_2d_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = false

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
