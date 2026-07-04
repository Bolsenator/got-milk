class_name BaseItem

extends Area2D

var pop_distance_min: float = 24.0
var pop_distance_max: float = 48.0
var pop_duration: float = 1.0

func _ready():
	pop_and_land()

func pop_and_land():
	var angle: float = randf_range(0, TAU)
	var distance: float = randf_range(pop_distance_min, pop_distance_max)
	var landing_offset: Vector2 = Vector2.from_angle(angle) * distance
	var landing_position: Vector2 = position + landing_offset
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", landing_position, pop_duration)
	
	tween.finished.connect(_on_landed)

func _on_landed() -> void:
	if not is_instance_valid(self):
		return
	set_deferred("monitoring", true)
