extends Control

@onready var exp_bar_ui = $ExpBar
@onready var time_elapsed_ui = $TimeElapsed
@onready var player_level = $PlayerLevel
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

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	player.exp_changed.connect(_on_exp_changed)
	player.level_up.connect(_on_level_up)
	exp_bar_ui.max_value = player.max_exp
	exp_bar_ui.value = player.current_exp
	player_level.text = "Lvl " + str(player.player_level)
	
	upgrade_scenes = {
		"summon_minion": summon_minion_scene,
		"max_health_modifier": max_health_scene,
		"health_regen_per_sec_modifier": health_regen_per_sec_scene,
		"damage_reduction_modifier": damage_reduction_scene,
		"player_movement_speed_modifier": player_movement_speed_scene,
		"exp_gain_modifier": exp_gain_scene,
		"damage_modifier": damage_scene,
		"attack_cooldown_modifier": attack_cooldown_scene,
		"minion_movement_speed_modifier": minion_movement_speed_scene,
		"crit_chance_modifier": crit_chance_scene,
		"crit_damage_modifier": crit_damage_scene,
		"multi_attack_modifier": multi_attack_scene
	}

func _on_exp_changed(new_exp, max_exp):
	exp_bar_ui.max_value = max_exp
	exp_bar_ui.value = new_exp

func _on_level_up(new_player_level):
	player_level.text = "Lvl " + str(new_player_level)

func update_time_elapsed(time_elapsed: float):
	@warning_ignore("integer_division") # Integer division intentional to get minutes and drop the decimal
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	time_elapsed_ui.text = str("%02d:%02d" % [minutes, seconds])

func update_upgrades_display(upgrade: Dictionary) -> void:
	var stat = upgrade["stat"]

	if !active_upgrade_widgets.has(stat):
		var new_widget = upgrade_scenes[stat].instantiate()
		upgrades_display.add_child(new_widget)
		active_upgrade_widgets[stat] = new_widget
	
	active_upgrade_widgets[stat].update_display(upgrade)

func create_offscreen_indicator(objective):
	var new_indicator = offscreen_indicator_scene.instantiate()
	new_indicator.initialize(objective)
	offscreen_indicators_container.add_child(new_indicator)
