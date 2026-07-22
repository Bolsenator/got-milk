extends Control

@onready var exp_bar_ui: TextureProgressBar = $ExpBar
@onready var time_elapsed_ui: Label = $TimeElapsed
@onready var player_level: Label = $PlayerLevel
@onready var upgrades_display: HBoxContainer = $UpgradesDisplay
@onready var offscreen_indicators_container: Node2D = $OffscreenIndicatorsContainer

@export var summon_minion_scene: PackedScene
@export var max_health_scene: PackedScene
@export var health_regen_per_sec_scene: PackedScene
@export var damage_reduction_scene: PackedScene
@export var player_movement_speed_scene: PackedScene
@export var exp_gain_scene: PackedScene
@export var damage_scene: PackedScene
@export var attack_cooldown_scene: PackedScene
@export var minion_movement_speed_scene: PackedScene
@export var crit_chance_scene: PackedScene
@export var crit_damage_scene: PackedScene
@export var multi_attack_scene: PackedScene

var offscreen_indicator_scene: PackedScene = preload("res://entities/helpers/offscreen_indicator.tscn")

var upgrade_scenes: Dictionary
var active_upgrade_widgets: Dictionary

func _ready() -> void:
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	player.exp_changed.connect(_on_exp_changed)
	player.level_up.connect(_on_level_up)
	exp_bar_ui.max_value = player.max_exp
	exp_bar_ui.value = player.current_exp
	player_level.text = "Lvl " + str(player.player_level)
	
	upgrade_scenes = {
		UpgradeDefinition.Stat.SUMMON_MINION: summon_minion_scene,
		UpgradeDefinition.Stat.MAX_HEALTH: max_health_scene,
		UpgradeDefinition.Stat.HEALTH_REGEN: health_regen_per_sec_scene,
		UpgradeDefinition.Stat.DAMAGE_REDUCTION: damage_reduction_scene,
		UpgradeDefinition.Stat.PLAYER_MOVEMENT_SPEED: player_movement_speed_scene,
		UpgradeDefinition.Stat.EXP_GAIN: exp_gain_scene,
		UpgradeDefinition.Stat.DAMAGE: damage_scene,
		UpgradeDefinition.Stat.ATTACK_COOLDOWN: attack_cooldown_scene,
		UpgradeDefinition.Stat.MINION_MOVEMENT_SPEED: minion_movement_speed_scene,
		UpgradeDefinition.Stat.CRIT_CHANCE: crit_chance_scene,
		UpgradeDefinition.Stat.CRIT_DAMAGE: crit_damage_scene,
		UpgradeDefinition.Stat.MULTI_ATTACK: multi_attack_scene
	}

func _on_exp_changed(new_exp: float, max_exp: float) -> void:
	exp_bar_ui.max_value = max_exp
	exp_bar_ui.value = new_exp

func _on_level_up(new_player_level: int) -> void:
	player_level.text = "Lvl " + str(new_player_level)

func update_time_elapsed(time_elapsed: float) -> void:
	@warning_ignore("integer_division") # Integer division intentional to get minutes and drop the decimal
	var minutes: int = int(time_elapsed) / 60
	var seconds: int = int(time_elapsed) % 60
	time_elapsed_ui.text = str("%02d:%02d" % [minutes, seconds])

func update_upgrades_display(upgrade: UpgradeDefinition, count: int) -> void:
	var stat: UpgradeDefinition.Stat = upgrade.stat
	if !active_upgrade_widgets.has(stat):
		var new_widget: Control = upgrade_scenes[stat].instantiate()
		upgrades_display.add_child(new_widget)
		active_upgrade_widgets[stat] = new_widget
	active_upgrade_widgets[stat].update_display(upgrade, count)

func create_offscreen_indicator(objective: Node) -> void:
	var new_indicator: Node2D = offscreen_indicator_scene.instantiate()
	new_indicator.initialize(objective)
	offscreen_indicators_container.add_child(new_indicator)
