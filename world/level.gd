# Manager for the currently loaded level. Coordinates the player, minions, enemies, other entities, enemy spawning, and player upgrades.

extends Node

@onready var y_sort_container: Node2D = $YSortContainer
@onready var player: CharacterBody2D = $YSortContainer/Player
@onready var ui: CanvasLayer = $UI
@onready var enemy_spawner: Node = $EnemySpawner

var time_elapsed: float = 0.0

var minion: PackedScene = preload("res://entities/minion/minion.tscn")
var exp_small: PackedScene = preload("res://entities/exp/exp_small.tscn")
var exp_large: PackedScene = preload("res://entities/exp/exp_large.tscn")
var crit_indicator_scene: PackedScene = preload("res://animations/crit.tscn")
var exp_drop_size_threshold: float = 25.0
var exp_increase_per_level: float = 1.3
var number_of_upgrade_choices: int = 5

@export var upgrade_pool: Array[UpgradeDefinition] = []
@export var wave_set: WaveSet

var upgrade_counts: Dictionary = {} # stat name -> int
signal level_up_reward_chosen

func _ready() -> void:
	
	# Connect signals
	player.level_up.connect(_on_level_up)
	player.player_died.connect(_on_game_over)
	ui.level_up_ui.apply_upgrade.connect(_on_apply_upgrade)
	ui.pause_ui.resume.connect(_on_resume_from_pause)
	enemy_spawner.enemy_died.connect(_on_enemy_died)
	enemy_spawner.wave_set_completed.connect(_level_completed)
	for upgrade_item: UpgradeItem in get_tree().get_nodes_in_group("upgrade_item"):
		upgrade_item.apply_upgrade_item.connect(_on_apply_upgrade_item)
		upgrade_item.create_offscreen_indicator.connect(_on_create_offscreen_indicator)
		upgrade_item._on_level_ready()
	
	# Initialize upgrade count array
	for upgrade: UpgradeDefinition in upgrade_pool:
		upgrade_counts[upgrade.stat] = 0
	
	spawn_starting_minions()
	enemy_spawner.initialize(wave_set, player, y_sort_container)
	enemy_spawner.start_enemy_spawns()

func _process(delta: float) -> void:
	# Keep run time updated
	if not get_tree().paused:
		time_elapsed += delta
		ui.hud_ui.update_time_elapsed(time_elapsed)

func spawn_starting_minions() -> void:
	for upgrade: UpgradeDefinition in upgrade_pool:
		if upgrade.target == UpgradeDefinition.Target.SUMMON_MINION:
			apply_upgrade(upgrade)

func apply_upgrade(upgrade: UpgradeDefinition) -> void:
	match upgrade.target:
		UpgradeDefinition.Target.SUMMON_MINION:
			summon_minion()
		UpgradeDefinition.Target.PLAYER:
			player.apply_upgrade(upgrade)
		UpgradeDefinition.Target.MINION:
			for current_minion: CharacterBody2D in get_tree().get_nodes_in_group("minion"):
				current_minion.apply_upgrade(upgrade)
	
	upgrade_counts[upgrade.stat] += 1
	ui.hud_ui.update_upgrades_display(upgrade, upgrade_counts[upgrade.stat])

func _on_level_up(_player_level: int) -> void:
	get_tree().paused = true
	upgrade_pool.shuffle()
	var current_upgrade_options: Array
	for upgrade: UpgradeDefinition in upgrade_pool:
		if upgrade_counts[upgrade.stat] < upgrade.max_count:
			current_upgrade_options.append(upgrade)
		if current_upgrade_options.size() >= number_of_upgrade_choices:
			break
	ui.level_up_ui.populate_upgrade_buttons(current_upgrade_options)
	ui.show_level_up_ui()

func _on_apply_upgrade(upgrade: UpgradeDefinition) -> void:
	apply_upgrade(upgrade)
	
	# Handle UI updates
	get_tree().paused = false
	ui.hide_level_up_ui()
	level_up_reward_chosen.emit() # Signal to reset exp bar after choosing upgrade
	player.max_exp *= exp_increase_per_level

func _on_apply_upgrade_item(_stat: UpgradeDefinition.Stat) -> void:
	for upgrade: UpgradeDefinition in upgrade_pool:
		if upgrade.stat == _stat:
			apply_upgrade(upgrade)
			return

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func summon_minion() -> void:
	var minion_instance: CharacterBody2D = minion.instantiate()
	minion_instance.global_position = player.global_position
	minion_instance.crit_landed.connect(_on_minion_crit_landed)
	y_sort_container.add_child(minion_instance)
	for upgrade: UpgradeDefinition in upgrade_pool:
		if upgrade.target == UpgradeDefinition.Target.MINION:
			for i: int in upgrade_counts[upgrade.stat]:
				minion_instance.apply_upgrade(upgrade)

func _on_minion_crit_landed(enemy_position: Vector2) -> void:
	var crit_indicator: Node2D = crit_indicator_scene.instantiate()
	crit_indicator.global_position = enemy_position
	add_child(crit_indicator)

func _on_resume_from_pause() -> void:
	toggle_pause()

func _on_game_over() -> void:
	get_tree().paused = true
	ui.show_game_over_ui()

func _on_enemy_died(exp_value: float, position: Vector2) -> void:
	if exp_value < exp_drop_size_threshold:
		var exp_instance: Area2D = exp_small.instantiate()
		y_sort_container.add_child(exp_instance)
		exp_instance.initialize(exp_value, position)
	else:
		var exp_instance: Area2D = exp_large.instantiate()
		y_sort_container.add_child(exp_instance)
		exp_instance.initialize(exp_value, position)

func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	ui.toggle_pause_ui()

func _on_create_offscreen_indicator(objective: UpgradeItem) -> void:
	ui.hud_ui.create_offscreen_indicator(objective)

func _level_completed() -> void:
	get_tree().paused = true
	ui.show_level_complete_ui()
