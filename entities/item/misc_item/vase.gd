extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

signal create_offscreen_indicator(_entity: Node, _texture: Texture2D)

var healing_potion_scene: PackedScene = preload("res://entities/item/misc_item/healing_potion.tscn")
var milk_bucket_scene: PackedScene = preload("res://entities/item/misc_item/milk_bucket.tscn")

var loot_table: Array = [
	healing_potion_scene,
	milk_bucket_scene
]

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_deferred("monitoring", false)
		animated_sprite.play("break")
		var loot_scene: PackedScene = loot_table.pick_random()
		var new_loot: BaseItem = loot_scene.instantiate()
		new_loot.create_offscreen_indicator.connect(_on_create_offscreen_indicator)
		call_deferred("add_child", new_loot)

func _on_create_offscreen_indicator(_entity: Node, _texture: Texture2D) -> void:
	create_offscreen_indicator.emit(_entity, _texture)
