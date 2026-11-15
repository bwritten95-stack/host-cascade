class_name HostBody
extends CharacterBody2D
## AI host — possessable. While unpossessed, hunts the player.

var def: HostDef
var hp: int = 4
var alive: bool = true
var possessed: bool = false
var _cd: float = 0.0
var _player: Node2D
var _aggro: float = 0.0

@onready var _visual: Polygon2D = $Visual

func setup(host_id: String) -> void:
	def = HostCatalog.make(host_id)
	hp = def.max_hp
	_apply_visual()

func _ready() -> void:
	add_to_group("host")
	add_to_group("hostile")
	if def == null:
		setup("grunt")
	RunState.hostiles_alive += 1
	_cd = randf_range(0.2, 0.8)

func _exit_tree() -> void:
	if alive and not possessed:
		RunState.hostiles_alive = max(RunState.hostiles_alive - 1, 0)

func _apply_visual() -> void:
	_visual.color = def.color
	var r := def.radius
	_visual.polygon = PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.8, -r * 0.15), Vector2(r * 0.5, r * 0.8),
		Vector2(-r * 0.5, r * 0.8), Vector2(-r * 0.8, -r * 0.15)
	])
	var cs := $CollisionShape2D
	if cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = r * 0.65

func _physics_process(delta: float) -> void:
	if not alive or possessed or not RunState.run_active:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_cd = maxf(_cd - delta, 0.0)
	_ai(delta)
	move_and_slide()
	_keep()

func _ai(_delta: float) -> void:
	if _player == null:
		return
	var to_p := _player.global_position - global_position
	var dist := to_p.length()
	match def.attack_kind:
		"spit":
			if dist < 220.0:
				velocity = -to_p.normalized() * def.speed * 0.6
			else:
				velocity = to_p.normalized() * def.speed
			if dist < 360.0 and _cd <= 0.0:
				_spit()
				_cd = def.attack_cooldown
		"dash":
			velocity = to_p.normalized() * def.speed
			if dist < 160.0 and _cd <= 0.0:
				velocity = to_p.normalized() * def.speed * 2.8
				_cd = def.attack_cooldown
				_try_melee()
		"slam", "apex":
			velocity = to_p.normalized() * def.speed
			if dist < 70.0 and _cd <= 0.0:
				_try_melee()
				_cd = def.attack_cooldown
				if def.attack_kind == "apex" and randf() < 0.4:
					_spit()
		_:
			velocity = to_p.normalized() * def.speed
			if dist < 46.0 and _cd <= 0.0:
				_try_melee()
				_cd = def.attack_cooldown
	rotation = lerp_angle(rotation, to_p.angle() + PI * 0.5, 0.15)

func _try_melee() -> void:
	if _player and _player.has_method("take_damage"):
		if global_position.distance_to(_player.global_position) < 52.0:
			_player.call("take_damage", def.damage)

func _spit() -> void:
	if _player == null:
		return
	var scene: PackedScene = preload("res://scenes/entities/hostile_projectile.tscn")
	var bolt: Node2D = scene.instantiate() as Node2D
	bolt.global_position = global_position
	get_parent().add_child(bolt)
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	if bolt.has_method("launch"):
		bolt.call("launch", dir * 280.0, def.damage, false)

func take_damage(amount: int, by_player: bool = false) -> void:
	if not alive or possessed:
		return
	hp -= amount
	_visual.modulate = Color(1.6, 1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		_die(by_player)

func _die(by_player: bool) -> void:
	alive = false
	RunState.hostiles_alive = max(RunState.hostiles_alive - 1, 0)
	if by_player:
		RunState.kills += 1
		RunState.add_essence(def.essence)
		RunState.bump_combo()
	EventBus.host_killed.emit(global_position, def.essence if by_player else 0, by_player)
	AudioService.play_kill()
	# Brood split
	if def.id == "brood" and by_player:
		for i in 2:
			var child_scene: PackedScene = preload("res://scenes/entities/host.tscn")
			var baby: Node2D = child_scene.instantiate() as Node2D
			baby.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			get_parent().call_deferred("add_child", baby)
			baby.call_deferred("setup", "grunt")
	_burst()
	queue_free()

func on_possessed() -> void:
	possessed = true
	alive = false
	RunState.hostiles_alive = max(RunState.hostiles_alive - 1, 0)
	remove_from_group("hostile")

func _burst() -> void:
	for i in 4:
		var fx := Polygon2D.new()
		fx.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
		fx.color = def.color
		fx.global_position = global_position
		get_parent().add_child(fx)
		var dir := Vector2.from_angle(TAU * float(i) / 4.0)
		var tw := fx.create_tween()
		tw.tween_property(fx, "global_position", global_position + dir * 40.0, 0.25)
		tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.25)
		tw.tween_callback(fx.queue_free)

func _keep() -> void:
	global_position.x = clampf(global_position.x, 36.0, 1244.0)
	global_position.y = clampf(global_position.y, 36.0, 684.0)
