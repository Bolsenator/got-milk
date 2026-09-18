class_name MinionLoadout
extends Resource

@export var loadout: Dictionary[MinionTypeId.Type, int] = {} 	# MinionType -> count: int
