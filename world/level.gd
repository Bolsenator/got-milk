extends Node

const WAVES: Array = [
	{"time": 60.0,  "enemy_type": "slime",  "count": 3, "interval": 5.0, "boss": null},
	{"time": 120.0,  "enemy_type": "snake",  "count": 6, "interval": 4.0, "boss": "bat"},
	{"time": 180.0,  "enemy_type": "slime",  "count": 12, "interval": 3.0, "boss": "bat"},
	{"time": 240.0,  "enemy_type": "spider",  "count": 6, "interval": 4.0, "boss": null},
	{"time": 300.0, "enemy_type": "spider",  "count": 8, "interval": 3.0, "boss": "wasps"},
	{"time": 360.0, "enemy_type": "bat",  "count": 12, "interval": 2.5, "boss": null},
	{"time": 420.0, "enemy_type": "spider",  "count": 12, "interval": 3.0, "boss": "demon"},
	{"time": 480.0, "enemy_type": "wasps",  "count": 8, "interval": 4.0, "boss": null},
	{"time": 540.0, "enemy_type": "spider",  "count": 14, "interval": 2.5, "boss": "demon"},
	{"time": 600.0, "enemy_type": "spider",  "count": 12, "interval": 3.0, "boss": null},
	{"time": 660.0, "enemy_type": "spider",  "count": 12, "interval": 2.5, "boss": "golem"},
	{"time": 720.0, "enemy_type": "wasps",  "count": 20, "interval": 2.5, "boss": null},
	{"time": 780.0, "enemy_type": "spider",  "count": 16, "interval": 2.5, "boss": "beholder"},
	{"time": 840.0, "enemy_type": "demon",  "count": 8, "interval": 3.0, "boss": null},
	{"time": 900.0, "enemy_type": "demon",  "count": 12, "interval": 2.5, "boss": null},
	{"time": 960.0, "enemy_type": "wasps",  "count": 30, "interval": 1.0, "boss": "beholder"},
	{"time": 1020.0, "enemy_type": "demon",  "count": 12, "interval": 2.5, "boss": "beholder"},
	{"time": 1080.0, "enemy_type": "golem",  "count": 8, "interval": 3.0, "boss": null},
	{"time": 1140.0, "enemy_type": "golem",  "count": 12, "interval": 2.5, "boss": null},
	{"time": 1200.0, "enemy_type": "wasps",  "count": 40, "interval": 1.0, "boss": "beholder"},
	{"time": 1260.0, "enemy_type": "golem",  "count": 16, "interval": 2.0, "boss": null},
	{"time": 1320.0, "enemy_type": "beholder",  "count": 8, "interval": 2.5, "boss": null},
	{"time": 1380.0, "enemy_type": "wasps",  "count": 60, "interval": 1.0, "boss": "beholder"},
	{"time": 1440.0, "enemy_type": "beholder",  "count": 12, "interval": 2.5, "boss": "devil"},
]

@onready var y_sort_container = $YSortContainer
@onready var player = $YSortContainer/Player
@onready var ui = $UI
@onready var spawn_timer = $SpawnTimer

var time_elapsed: float = 0.0
var current_wave_idx: int = 0
var current_wave: Dictionary = WAVES[current_wave_idx]
var despawn_threshold_ms: int = 30000
var despawn_timer_s: float = 1.0

var minion = preload("res://entities/minion/minion.tscn")
var exp_small = preload("res://entities/exp/exp_small.tscn")
var exp_large = preload("res://entities/exp/exp_large.tscn")
var crit_indicator_scene = preload("res://animations/crit.tscn")

var exp_drop_size_threshold: float = 25.0
var exp_increase_per_level: float = 1.3

var enemy_spawn_distance_min: float = 900.0
var enemy_spawn_distance_max: float = 1200.0
var enemy_collision_layers: Array = [1] # list of collision layers to check against when spawning enemy
const ENEMY_SCENES: Dictionary = {
	"slime" 	: preload("res://entities/enemy/green_slime/green_slime.tscn"),
	"snake" 	: preload("res://entities/enemy/snake/snake.tscn"),
	"bat" 		: preload("res://entities/enemy/bat/bat.tscn"),
	"spider" 	: preload("res://entities/enemy/spider/spider.tscn"),
	"wasps" 	: preload("res://entities/enemy/wasps/wasps.tscn"),
	"demon" 	: preload("res://entities/enemy/demon/demon.tscn"),
	"golem" 	: preload("res://entities/enemy/golem/golem.tscn"),
	"beholder" 	: preload("res://entities/enemy/beholder/beholder.tscn"),
	"devil" 	: preload("res://entities/enemy/devil/devil.tscn")
}

var number_of_upgrade_choices: int = 5

@export var upgrade_pool: Array[UpgradeDefinition] = []
@export var waves: Array[WaveDefinition] = []

var upgrade_counts: Dictionary = {} # stat name -> int
signal level_up_reward_chosen

func _ready():
	
	# Connect signals
	player.level_up.connect(_on_level_up)
	player.player_died.connect(_on_game_over)
	ui.level_up_ui.apply_upgrade.connect(_on_apply_upgrade)
	ui.pause_ui.resume.connect(_on_resume_from_pause)
	for upgrade_item in get_tree().get_nodes_in_group("upgrade_item"):
		upgrade_item.apply_upgrade_item.connect(_on_apply_upgrade_item)
		upgrade_item.create_offscreen_indicator.connect(_on_create_offscreen_indicator)
		upgrade_item._on_level_ready()
	
	# Initialize upgrade count array
	for upgrade in upgrade_pool:
		upgrade_counts[upgrade.stat] = 0
	
	spawn_timer.wait_time = current_wave.interval
	spawn_starting_minions()

func _process(delta: float):
	# Keep run time updated
	if not get_tree().paused:
		time_elapsed += delta
		ui.hud_ui.update_time_elapsed(time_elapsed)
	
	# Spawn enemies
	if current_wave_idx < WAVES.size() -1 and time_elapsed >= current_wave.time:
		current_wave_idx += 1
		current_wave = WAVES[current_wave_idx]
		spawn_timer.wait_time = current_wave.interval
		if current_wave.boss:
			spawn_boss(current_wave.boss)

func spawn_boss(boss_type):
	var boss_instance = ENEMY_SCENES[boss_type].instantiate()
	boss_instance.global_position = get_enemy_spawn_position()
	y_sort_container.add_child(boss_instance)
	boss_instance.died.connect(_on_enemy_died)

func spawn_starting_minions():
	for upgrade in upgrade_pool:
		if upgrade.target == UpgradeDefinition.Target.SUMMON_MINION:
			apply_upgrade(upgrade)

func apply_upgrade(upgrade: UpgradeDefinition):
	match upgrade.target:
		UpgradeDefinition.Target.SUMMON_MINION:
			summon_minion()
		UpgradeDefinition.Target.PLAYER:
			player.apply_upgrade(upgrade)
		UpgradeDefinition.Target.MINION:
			for current_minion in get_tree().get_nodes_in_group("minion"):
				current_minion.apply_upgrade(upgrade)
	
	upgrade_counts[upgrade.stat] += 1
	ui.hud_ui.update_upgrades_display(upgrade, upgrade_counts[upgrade.stat])

func _on_spawn_timer_timeout():
	for i in range(current_wave.count):
		var enemy_instance = ENEMY_SCENES[current_wave.enemy_type].instantiate()
		enemy_instance.global_position = get_enemy_spawn_position()
		y_sort_container.add_child(enemy_instance)
		enemy_instance.died.connect(_on_enemy_died)

func _on_level_up(_player_level):
	get_tree().paused = true
	upgrade_pool.shuffle()
	var current_upgrade_options: Array
	for upgrade in upgrade_pool:
		if upgrade_counts[upgrade.stat] < upgrade.max_count:
			current_upgrade_options.append(upgrade)
		if current_upgrade_options.size() >= number_of_upgrade_choices:
			break
	ui.level_up_ui.populate_upgrade_buttons(current_upgrade_options)
	ui.show_level_up_ui()

func _on_apply_upgrade(upgrade: UpgradeDefinition):
	apply_upgrade(upgrade)
	
	# Handle UI updates
	get_tree().paused = false
	ui.hide_level_up_ui()
	level_up_reward_chosen.emit() # Signal to reset exp bar after choosing upgrade
	player.max_exp *= exp_increase_per_level

func _on_apply_upgrade_item(stat: String):
	for upgrade in upgrade_pool:
		if upgrade.stat == stat:
			apply_upgrade(upgrade)
			return

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func summon_minion():
	var minion_instance = minion.instantiate()
	minion_instance.global_position = player.global_position
	for upgrade in upgrade_pool:
		if upgrade.target == UpgradeDefinition.Target.MINION:
			for i in upgrade_counts[upgrade.stat]:
				minion_instance.apply_upgrade(upgrade)
	minion_instance.crit_landed.connect(_on_minion_crit_landed)
	y_sort_container.add_child(minion_instance)

func _on_minion_crit_landed(enemy_position: Vector2):
	var crit_indicator = crit_indicator_scene.instantiate()
	crit_indicator.global_position = enemy_position
	add_child(crit_indicator)

func _on_resume_from_pause():
	toggle_pause()

func _on_game_over():
	get_tree().paused = true
	ui.show_game_over_ui()

func _on_enemy_died(exp_value: float, position: Vector2):
	if exp_value < exp_drop_size_threshold:
		var exp_instance = exp_small.instantiate()
		y_sort_container.add_child(exp_instance)
		exp_instance.initialize(exp_value, position)
	else:
		var exp_instance = exp_large.instantiate()
		y_sort_container.add_child(exp_instance)
		exp_instance.initialize(exp_value, position)

func toggle_pause():
	get_tree().paused = !get_tree().paused
	ui.toggle_pause_ui()

func get_enemy_spawn_position() -> Vector2:
	var angle
	var distance
	var enemy_spawn_position
	
	var max_spawn_attempts = 100 # Prevents too many failed spawn attempts, quietly stops attempting
	var current_spawn_attempts = 0
	
	# Generate random location until valid
	while current_spawn_attempts < max_spawn_attempts:
		current_spawn_attempts += 1
		angle = randf() * TAU
		distance = randf_range(enemy_spawn_distance_min,enemy_spawn_distance_max)
		enemy_spawn_position = player.global_position + ( Vector2(cos(angle), sin(angle)) * distance )
		if(is_valid_spawn_location(enemy_spawn_position)):
			break
	
	return enemy_spawn_position

func is_valid_spawn_location(spawn_position: Vector2) -> bool:
	var collision_query_point = PhysicsPointQueryParameters2D.new()
	collision_query_point.position = spawn_position
	
	for layer_number in enemy_collision_layers:
		collision_query_point.collision_mask = 1 << (layer_number - 1)
	
	var space_state = get_viewport().get_world_2d().direct_space_state
	var collision_array = space_state.intersect_point(collision_query_point)
	
	if collision_array.size() == 0:
		return true
	else:
		return false

func _on_despawn_timer_timeout() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if Time.get_ticks_msec() - enemy.spawn_time_ms > despawn_threshold_ms and !enemy.on_screen_notifier.is_on_screen():
			enemy.queue_free()

func _on_create_offscreen_indicator(objective) -> void:
	ui.hud_ui.create_offscreen_indicator(objective)
	
