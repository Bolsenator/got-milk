# Resource which holds the list of enemy waves per level as an Array of WaveDefinition resources. Each level is assigned one WaveSet.

class_name WaveSet
extends Resource

@export var set_name: String
@export var waves: Array[WaveDefinition]
@export var loop_last_wave: bool
