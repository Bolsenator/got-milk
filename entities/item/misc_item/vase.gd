extends Area2D

@onready var animated_sprite = $AnimatedSprite2D

var is_broken: bool = false

var healing_potion_scene = preload("res://entities/item/misc_item/healing_potion.tscn")
var milk_bucket_scene = preload("res://entities/item/misc_item/milk_bucket.tscn")

var loot_table: Array = [
	healing_potion_scene,
	milk_bucket_scene
]

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !is_broken:
		animated_sprite.play("break")
		is_broken = true
		var loot_scene = loot_table.pick_random()
		var new_loot = loot_scene.instantiate()
		add_child(new_loot)
