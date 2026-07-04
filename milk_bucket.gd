extends BaseItem

var speed: float = 500.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		for exp_instance in get_tree().get_nodes_in_group("exp"):
			exp_instance.enable_magnet(body, speed)
		queue_free()
