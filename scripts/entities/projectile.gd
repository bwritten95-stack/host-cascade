extends Area2D

var _vel: Vector2 = Vector2.ZERO
var _dmg: int = 1
var _from_player: bool = false
var _life: float = 2.8

func launch(vel: Vector2, dmg: int, from_player: bool) -> void:
	_vel = vel
	_dmg = dmg
	_from_player = from_player
	if from_player:
		add_to_group("player_projectile")
		collision_mask = 8 # hostile layer bit? use groups in handler
	else:
		add_to_group("hostile_projectile")
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)

func _physics_process(delta: float) -> void:
	position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body(body: Node2D) -> void:
	if _from_player and body.is_in_group("hostile") and body.has_method("take_damage"):
		body.call("take_damage", _dmg, true)
		queue_free()
	elif not _from_player and body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", _dmg)
		queue_free()

func _on_area(area: Area2D) -> void:
	if _from_player and area.is_in_group("hostile_projectile"):
		area.queue_free()
		queue_free()
