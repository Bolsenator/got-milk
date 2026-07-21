extends Node2D

var objective: Node
var player: CharacterBody2D

var left_margin: float = 64.0
var top_margin: float = 192.0
var right_margin: float = 64.0
var bottom_margin: float = 64.0

@onready var arrow_sprite: Sprite2D = $ArrowSprite

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func initialize(_objective: Node) -> void:
	objective = _objective
	objective.tree_exited.connect(_on_objective_tree_exited)

func _process(_delta: float) -> void:
	
	# Get viewport and objective position
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var objective_position: Vector2 = get_viewport().get_canvas_transform() * objective.global_position
	
	# Hide or show
	if viewport_rect.has_point(objective_position):
		hide()
	else:
		show()
		# Add margin and clamp to canvas
		var bounds: Rect2 = viewport_rect.grow_individual(-left_margin, -top_margin, -right_margin, -bottom_margin)
		position = objective_position.clamp(bounds.position, bounds.position + bounds.size)
	

	arrow_sprite.look_at(objective_position)

func _on_objective_tree_exited() -> void:
	queue_free()
