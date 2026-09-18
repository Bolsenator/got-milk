# Resouce which contains data for one wave. Contains an array of WaveEnemyEntry resources to allow for multiple types of enemies to spawn per wave.

class_name WaveDefinition
extends Resource

enum WaveAdvanceMode { TIMED, CLEARED, TIMED_OR_CLEARED, BOSS_CLEARED }

@export var enemy_entries: Array[WaveEnemyEntry]
@export var wave_advance_mode: WaveAdvanceMode
@export var duration: float
@export_group("Boss")
@export var boss_scene: PackedScene # optional, null if no boss this wave
@export var boss_spawn_delay: float
