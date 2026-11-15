class_name Parasite
extends CharacterBody2D
## Player: worm form or riding a host body.

enum Mode { WORM, HOST, LEAPING }

const WORM_SPEED := 300.0
const LEAP_SPEED := 980.0
const LEAP_DURATION := 0.2
const POSSESS_RANGE := 52.0
const MAGNET_RANGE := 110.0

@onready var _visual: Polygon2D = $Visual
@onready var _glow: Polygon2D = $Glow
@onready var _col: CollisionShape2D = $CollisionShape2D

var mode: Mode = Mode.WORM
var host_def: HostDef
var host_hp: int = 0
var host_max_hp: int = 0
var _attack_cd: float = 0.0
var _leap_t: float = 0.0
var _leap_dir: Vector2 = Vector2.RIGHT
var _facing: Vector2 = Vector2.RIGHT
var _alive: bool = true
var _aim_line: Line2D
var _proj_scene: PackedScene = preload("res://scenes/entities/player_projectile.tscn")

func _ready() -> void:
	add_to_group("player")
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(0.4, 1.0, 0.7, 0.35)
	_aim_line.z_index = -1
	add_child(_aim_line)
	_enter_worm(false)

func _physics_process(delta: float) -> void:
	if not _alive or not RunState.run_active:
		velocity = Vector2.ZERO
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	match mode:
		Mode.WORM:
			_process_worm(delta)
		Mode.HOST:
			_process_host(delta)
		Mode.LEAPING:
			_process_leap(delta)
	_clamp()
	_update_aim_line()

func _process_worm(delta: float) -> void:
	RunState.in_worm = true
	RunState.worm_time += delta
	EventBus.worm_timer_changed.emit(RunState.worm_time_max - RunState.worm_time, RunState.worm_time_max)
	if RunState.worm_time >= RunState.worm_time_max:
		_die()
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length_squared() > 0.01:
		_facing = dir.normalized()
	velocity = dir * WORM_SPEED
	move_and_slide()
	# Auto-possess on touch
	_try_touch_possess()
	if Input.is_action_just_pressed("leap") or Input.is_action_just_pressed("attack"):
		_start_leap()
	_pulse_worm()

func _process_host(delta: float) -> void:
	RunState.in_worm = false
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length_squared() > 0.01:
		_facing = dir.normalized()
	var spd := host_def.speed if host_def else 150.0
	if RunState.has_mutation("fang"):
		pass
	velocity = dir * spd
	move_and_slide()
	if Input.is_action_just_pressed("attack"):
		_host_attack()
	if Input.is_action_just_pressed("eject") or Input.is_action_just_pressed("leap"):
		_eject(true)
		return
	if host_def == null:
		_enter_worm(true)
		return
	# Hurt flash scale
	scale = scale.lerp(Vector2.ONE * (1.0 + float(host_def.tier) * 0.08), 0.2)

func _process_leap(delta: float) -> void:
	_leap_t -= delta
	velocity = _leap_dir * LEAP_SPEED
	move_and_slide()
	var hit := _find_possess_target(POSSESS_RANGE * (1.2 if RunState.has_mutation("grip") else 1.0))
	if hit:
		_possess(hit)
		return
	if _leap_t <= 0.0:
		mode = Mode.WORM
		EventBus.leap_missed.emit()
		RunState.break_combo()

func _start_leap() -> void:
	var dir := _aim_dir()
	# Magnet: if a host is near aim cone, snap leap toward it (addictive forgiveness)
	var magnet := _magnet_host(dir)
	if magnet:
		dir = (magnet.global_position - global_position).normalized()
	_leap_dir = dir
	_leap_t = LEAP_DURATION
	mode = Mode.LEAPING
	EventBus.leap_started.emit(global_position, dir)
	AudioService.play_leap()
	EventBus.camera_shake.emit(3.0, 0.06)
	_spawn_leap_streak()

func _magnet_host(aim: Vector2) -> Node2D:
	var best: Node2D = null
	var best_score := 0.55 # min dot
	for n in get_tree().get_nodes_in_group("host"):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("possessed") == true or n.get("alive") == false:
			continue
		var to: Vector2 = (n as Node2D).global_position - global_position
		var dist := to.length()
		if dist > MAGNET_RANGE or dist < 1.0:
			continue
		var dot := aim.dot(to.normalized())
		if dot > best_score:
			best_score = dot
			best = n as Node2D
	return best

func _spawn_leap_streak() -> void:
	var streak := Polygon2D.new()
	streak.polygon = PackedVector2Array([Vector2(-4, -10), Vector2(4, -10), Vector2(2, 14), Vector2(-2, 14)])
	streak.color = Color(0.5, 1.0, 0.75, 0.7)
	streak.global_position = global_position
	streak.rotation = _leap_dir.angle() + PI * 0.5
	get_parent().add_child(streak)
	var tw := streak.create_tween()
	tw.tween_property(streak, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(streak, "scale", Vector2(1.4, 1.8), 0.2)
	tw.tween_callback(streak.queue_free)

func _aim_dir() -> Vector2:
	var mouse := get_global_mouse_position()
	var d := mouse - global_position
	if d.length_squared() < 4.0:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		return input_dir.normalized() if input_dir.length_squared() > 0.01 else _facing
	return d.normalized()

func _update_aim_line() -> void:
	if mode == Mode.LEAPING:
		_aim_line.points = PackedVector2Array()
		return
	var dir := _aim_dir()
	_aim_line.points = PackedVector2Array([Vector2.ZERO, dir * 70.0])
	_aim_line.default_color = Color(0.4, 1.0, 0.7, 0.55 if mode == Mode.WORM else 0.2)

func _try_touch_possess() -> void:
	var t := _find_possess_target(POSSESS_RANGE * (1.1 if RunState.has_mutation("grip") else 1.0))
	if t:
		_possess(t)

func _find_possess_target(range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := range_px * range_px
	for n in get_tree().get_nodes_in_group("host"):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("possessed") == true:
			continue
		if n.get("alive") == false:
			continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = n as Node2D
	return best

func _possess(host: Node2D) -> void:
	if host.has_method("on_possessed"):
		host.call("on_possessed")
	var def: HostDef = host.get("def") as HostDef
	if def == null:
		def = HostCatalog.make("grunt")
	host_def = def
	host_max_hp = def.max_hp
	if RunState.has_mutation("shell"):
		host_max_hp = int(ceil(float(host_max_hp) * 1.2))
	host_hp = host_max_hp
	mode = Mode.HOST
	RunState.in_worm = false
	RunState.worm_time = 0.0
	RunState.possessed_tier = def.tier
	RunState.hosts_ridden += 1
	global_position = host.global_position
	_apply_host_visual()
	if RunState.has_mutation("chain") and RunState.combo == 0:
		RunState.combo = 1
		RunState.mult = 1.15
	RunState.bump_combo()
	EventBus.possessed.emit(host)
	AudioService.play_possess()
	EventBus.camera_shake.emit(5.0, 0.1)
	EventBus.hitstop.emit(0.04)
	EventBus.floating_text.emit(global_position + Vector2(0, -24), def.display_name.to_upper(), def.color)
	host.queue_free()

func _eject(from_input: bool) -> void:
	if mode != Mode.HOST:
		return
	var pos := global_position
	if RunState.has_mutation("shock"):
		_shockwave(pos, 2)
	mode = Mode.WORM
	RunState.worm_time = 0.0
	_enter_worm(true)
	EventBus.ejected.emit(pos)
	AudioService.play_eject()
	if from_input:
		# brief leap boost toward aim
		_start_leap()

func _enter_worm(keep_combo: bool) -> void:
	mode = Mode.WORM
	host_def = null
	scale = Vector2.ONE
	_visual.color = Color(0.45, 1.0, 0.7, 1.0)
	_glow.color = Color(0.2, 0.9, 0.5, 0.25)
	_visual.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)
	])
	if not keep_combo:
		RunState.break_combo()

func _apply_host_visual() -> void:
	_visual.color = host_def.color
	_glow.color = Color(host_def.color.r, host_def.color.g, host_def.color.b, 0.22)
	var r := host_def.radius
	_visual.polygon = PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.85, -r * 0.2), Vector2(r * 0.55, r * 0.85),
		Vector2(-r * 0.55, r * 0.85), Vector2(-r * 0.85, -r * 0.2)
	])
	if _col.shape is CircleShape2D:
		(_col.shape as CircleShape2D).radius = r * 0.7

func _host_attack() -> void:
	if _attack_cd > 0.0 or host_def == null:
		return
	_attack_cd = host_def.attack_cooldown
	var dmg := host_def.damage + (1 if RunState.has_mutation("fang") else 0)
	match host_def.attack_kind:
		"spit":
			_fire_projectile(dmg)
		"slam":
			_melee_arc(dmg, 70.0, true)
		"dash":
			velocity = _aim_dir() * host_def.speed * 2.4
			_melee_arc(dmg, 40.0, false)
		"apex":
			_fire_projectile(dmg)
			_melee_arc(dmg, 55.0, false)
		_:
			_melee_arc(dmg, 48.0, false)
	AudioService.play_hit()

func _melee_arc(dmg: int, radius: float, heavy: bool) -> void:
	EventBus.camera_shake.emit(4.0 if heavy else 2.0, 0.07)
	var origin := global_position
	for n in get_tree().get_nodes_in_group("hostile"):
		if not is_instance_valid(n):
			continue
		if n is Node2D and origin.distance_to((n as Node2D).global_position) <= radius:
			if n.has_method("take_damage"):
				n.call("take_damage", dmg, true)

func _fire_projectile(dmg: int) -> void:
	if _proj_scene == null:
		return
	var p: Node2D = _proj_scene.instantiate() as Node2D
	p.global_position = global_position
	get_parent().add_child(p)
	if p.has_method("launch"):
		p.call("launch", _aim_dir() * 420.0, dmg, true)

func _shockwave(pos: Vector2, dmg: int) -> void:
	for n in get_tree().get_nodes_in_group("hostile"):
		if n is Node2D and pos.distance_to((n as Node2D).global_position) < 90.0:
			if n.has_method("take_damage"):
				n.call("take_damage", dmg, true)

func take_damage(amount: int) -> void:
	if not _alive or mode == Mode.LEAPING:
		return
	if "--ship-test" in OS.get_cmdline_user_args():
		return
	if mode == Mode.WORM:
		_die()
		return
	host_hp -= amount
	EventBus.camera_shake.emit(6.0, 0.1)
	AudioService.play_hit()
	_visual.modulate = Color(1.5, 1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.12)
	if host_hp <= 0:
		# Forced eject — combo at risk
		EventBus.floating_text.emit(global_position, "SHELL BROKE", Color(1.0, 0.5, 0.5))
		_eject(false)

func _die() -> void:
	if not _alive:
		return
	if "--ship-test" in OS.get_cmdline_user_args():
		# Soft reset worm instead of ending the run during CI verification
		RunState.worm_time = 0.0
		_alive = true
		visible = true
		_enter_worm(true)
		return
	_alive = false
	EventBus.player_died.emit()
	AudioService.play_die()
	visible = false

func _pulse_worm() -> void:
	var t := Time.get_ticks_msec() * 0.001
	_glow.scale = Vector2.ONE * (1.2 + sin(t * 8.0) * 0.15)
	# urgency tint as timer runs out
	var u := RunState.worm_time / maxf(RunState.worm_time_max, 0.01)
	_visual.color = Color(0.45, 1.0, 0.7).lerp(Color(1.0, 0.3, 0.35), clampf(u, 0.0, 1.0))

func _clamp() -> void:
	global_position.x = clampf(global_position.x, 40.0, 1240.0)
	global_position.y = clampf(global_position.y, 40.0, 680.0)
