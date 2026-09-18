# Resource which contains one enemy type with spawn timings and counts within a wave.

class_name WaveEnemyEntry
extends Resource

@export var enemy_scene: PackedScene
@export var spawn_count: int			# number of enemies spawned at every interval
@export var spawn_interval: float		# spacing between spawns within wave
