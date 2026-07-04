extends BaseItem

var healing_amount: float = 50.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.heal(healing_amount)
		queue_free()
