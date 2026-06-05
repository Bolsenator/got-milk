extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.collect_milk_item()
		queue_free()
