# Script to handle spawning and despawning of enemies in the level.
# Script entry is made by the parent level scene which calls start_enemy_spawns() when the level is ready to begin the spawning

extends Node

@export_flags_2d_physics var spawn_collision_mask: int # collision layers to check against when spawning enemy

# Spawn and despawn values
var spawn_distance_min: float = 900.0 # distance from player
var spawn_distance_max: float = 1200.0 # distance from player
var despawn_threshold_ms: int = 30000 # 30 seconds before attempting to despawn an enemy

# These must be initialized from the parent node which has this data
var wave_set: WaveSet
var player: CharacterBody2D
var y_sort_container: Node2D

# Wave state
var current_wave: WaveDefinition
var _current_wave_index: int = 0

signal enemy_died(exp_value: float, _position: Vector2)
signal wave_set_completed()

@onready var wave_duration_timer: Node = $WaveDurationTimer
@onready var boss_delay: Node = $BossDelay
@onready var spawn_interval_container: Node = $SpawnIntervalContainer # Node holds a timer for each group of enemy spawning in the current wave

func initialize(_wave_set: WaveSet, _player: CharacterBody2D, _y_sort_container: Node2D) -> void:
	wave_set = _wave_set
	player = _player
	y_sort_container = _y_sort_container

func start_enemy_spawns() -> void:
	current_wave = wave_set.waves[_current_wave_index]
	wave_duration_timer.start(current_wave.duration)
	_set_spawn_interval_timers()
	if current_wave.boss_scene:
		boss_delay.start(current_wave.boss_spawn_delay)

func _set_spawn_interval_timers() -> void:
	
	# Clear timer container
	for child: Timer in spawn_interval_container.get_children():
		# Specifically removing child and then freeing, rather than just freeing because the next block of code adds new nodes
		# There is a possible delay if only queue_free is called, but I need to ensure it is removed from the parent and before moving forward
		spawn_interval_container.remove_child(child)
		child.queue_free()
	
	# Add new timers to container
	for enemy_entry: WaveEnemyEntry in current_wave.enemy_entries:
		# Create timer, set duration, connect signal
		var timer: Timer = Timer.new()
		timer.wait_time = enemy_entry.spawn_interval
		timer.timeout.connect(_on_spawn_timer_timeout.bind(enemy_entry))
		spawn_interval_container.add_child(timer)
		timer.start()

func _on_wave_duration_timer_timeout() -> void:
	if current_wave.wave_advance_mode == WaveDefinition.WaveAdvanceMode.TIMED:
		_current_wave_index += 1
		if _is_final_wave():
			wave_set_completed.emit()
		else:
			start_enemy_spawns()

func _on_enemy_died(_exp_value: float, _position: Vector2) -> void:
	enemy_died.emit(_exp_value, _position)

func _on_boss_died(_exp_value: float, _position: Vector2) -> void:
	enemy_died.emit(_exp_value, _position)
	if current_wave.wave_advance_mode == WaveDefinition.WaveAdvanceMode.BOSS_CLEARED:
		_current_wave_index += 1
		if _is_final_wave():
			wave_set_completed.emit()
		else:
			start_enemy_spawns()

func _on_spawn_timer_timeout(enemy_entry: WaveEnemyEntry) -> void:
	for i: int in enemy_entry.spawn_count:
		var enemy_instance: Node = enemy_entry.enemy_scene.instantiate()
		enemy_instance.global_position = _get_enemy_spawn_position()
		enemy_instance.died.connect(_on_enemy_died)
		y_sort_container.add_child(enemy_instance)

func _on_boss_delay_timeout() -> void:
	var boss_instance: Node = current_wave.boss_scene.instantiate()
	boss_instance.global_position = _get_enemy_spawn_position()
	boss_instance.died.connect(_on_boss_died)
	boss_instance.is_boss = true
	y_sort_container.add_child(boss_instance)

func _get_enemy_spawn_position() -> Vector2:
	var angle: float
	var distance: float
	var enemy_spawn_position : Vector2
	
	var max_spawn_attempts: int = 100 # Prevents too many failed spawn attempts, quietly stops attempting
	var current_spawn_attempts: int = 0
	
	# Generate random location until valid
	while current_spawn_attempts < max_spawn_attempts:
		current_spawn_attempts += 1
		angle = randf() * TAU
		distance = randf_range(spawn_distance_min, spawn_distance_max)
		enemy_spawn_position = player.global_position + ( Vector2(cos(angle), sin(angle)) * distance )
		if(_is_valid_spawn_location(enemy_spawn_position)):
			break
	
	return enemy_spawn_position

func _is_valid_spawn_location(spawn_position: Vector2) -> bool:
	var collision_query_point: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	collision_query_point.collision_mask = spawn_collision_mask
	collision_query_point.position = spawn_position
	
	var space_state: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var collision_array: Array = space_state.intersect_point(collision_query_point)
	
	return collision_array.size() == 0

func _on_despawn_timer_timeout() -> void:
	for enemy: EnemyBase in get_tree().get_nodes_in_group("enemy"):
		if Time.get_ticks_msec() - enemy.spawn_time_ms > despawn_threshold_ms and !enemy.on_screen_notifier.is_on_screen() and !enemy.is_boss:
			enemy.queue_free()

func _is_final_wave() -> bool:
	if _current_wave_index >= wave_set.waves.size():
		return true
	else:
		return false
