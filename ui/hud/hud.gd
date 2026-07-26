extends Control

@onready var exp_bar_ui: TextureProgressBar = $ExpBar
@onready var time_elapsed_ui: Label = $TimeElapsed
@onready var player_level: Label = $PlayerLevel
@onready var upgrades_display: HBoxContainer = $UpgradesDisplay
@onready var offscreen_indicators_container: Node2D = $OffscreenIndicatorsContainer

var offscreen_indicator_scene: PackedScene = preload("res://entities/helpers/offscreen_indicator.tscn")
var upgrade_widget_scene: PackedScene = preload("uid://n2d0gi6ngryu")
var active_upgrade_widgets: Dictionary

func _ready() -> void:
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	player.exp_changed.connect(_on_exp_changed)
	player.level_up.connect(_on_level_up)
	exp_bar_ui.max_value = player.max_exp
	exp_bar_ui.value = player.current_exp
	player_level.text = "Lvl " + str(player.player_level)

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
	var stat: StatId.Stat = upgrade.stat
	if !active_upgrade_widgets.has(stat):
		var new_widget: Control = upgrade_widget_scene.instantiate()
		upgrades_display.add_child(new_widget)
		new_widget.texture_rect.texture = upgrade.icon
		active_upgrade_widgets[stat] = new_widget
	active_upgrade_widgets[stat].update_display(upgrade, count)

func create_offscreen_indicator(entity: Node, texture: Texture2D) -> void:
	var new_indicator: Node2D = offscreen_indicator_scene.instantiate()
	offscreen_indicators_container.add_child(new_indicator)
	new_indicator.initialize(entity, texture)
