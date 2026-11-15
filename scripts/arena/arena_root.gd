extends Node2D

@onready var _entities: Node2D = $Entities
@onready var _director: RunDirector = $RunDirector
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $HUD
@onready var _pause: CanvasLayer = $PauseOverlay
@onready var _shop: CanvasLayer = $ShopOverlay
@onready var _extract: CanvasLayer = $ExtractOverlay
@onready var _bg: Node2D = $Background

var _parasite_scene: PackedScene = preload("res://scenes/entities/parasite.tscn")
var _shake: float = 0.0
var _shake_t: float = 0.0
var _hitstop: float = 0.0
var _ended: bool = false

func _ready() -> void:
	RunState.reset()
	_pause.visible = false
	_shop.visible = false
	_extract.visible = false
	EventBus.camera_shake.connect(_on_shake)
	EventBus.hitstop.connect(_on_hitstop)
	EventBus.player_died.connect(_on_dead)
	EventBus.run_won.connect(_on_won)
	EventBus.run_extracted.connect(_on_extracted)
	EventBus.floating_text.connect(_on_float)
	EventBus.biome_started.connect(_on_biome)
	EventBus.essence_gained.connect(func(amount: int, _total: int) -> void:
		var p := get_tree().get_first_node_in_group("player")
		if p is Node2D:
			EventBus.floating_text.emit((p as Node2D).global_position + Vector2(12, -30), "+%d" % amount, Color(0.45, 1.0, 0.7))
	)
	_director.request_shop.connect(_open_shop)
	_director.request_extract_choice.connect(_open_extract)
	_paint_bg(0)
	var p: Node2D = _parasite_scene.instantiate() as Node2D
	p.global_position = Vector2(640, 400)
	_entities.add_child(p)
	_director.start()
	var args := OS.get_cmdline_user_args()
	if "--ship-test" in args:
		add_child(preload("res://scripts/systems/ship_test_driver.gd").new())
	elif "--autoplay" in args:
		add_child(preload("res://scripts/systems/autoplay_driver.gd").new())

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and RunState.run_active and not _ended:
		var paused := not get_tree().paused
		get_tree().paused = paused
		_pause.visible = paused
	if _hitstop > 0.0:
		_hitstop -= delta
		Engine.time_scale = 0.12
	else:
		Engine.time_scale = 1.0
	if _shake_t > 0.0:
		_shake_t -= delta
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = lerpf(_shake, 0.0, 8.0 * delta)
	else:
		_camera.offset = Vector2.ZERO

func _on_shake(a: float, d: float) -> void:
	_shake = maxf(_shake, a)
	_shake_t = maxf(_shake_t, d)

func _on_hitstop(d: float) -> void:
	_hitstop = maxf(_hitstop, d)

func _on_float(pos: Vector2, text: String, color: Color) -> void:
	var lab := Label.new()
	lab.text = text
	lab.modulate = color
	lab.z_index = 30
	lab.global_position = pos + Vector2(-40, -20)
	lab.add_theme_font_size_override("font_size", 16)
	_entities.add_child(lab)
	var tw := lab.create_tween()
	tw.tween_property(lab, "global_position", lab.global_position + Vector2(0, -36), 0.55)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lab.queue_free)

func _on_biome(idx: int, _name: String) -> void:
	_paint_bg(idx)

func _open_shop() -> void:
	get_tree().paused = true
	_shop.visible = true
	_shop.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if _shop.has_method("open_shop"):
		_shop.call("open_shop")

func close_shop_and_continue() -> void:
	_shop.visible = false
	get_tree().paused = false
	_director.continue_after_shop()

func _open_extract() -> void:
	get_tree().paused = true
	_extract.visible = true
	_extract.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func extract_now() -> void:
	_extract.visible = false
	get_tree().paused = false
	_director.choose_extract()

func greed_apex() -> void:
	_extract.visible = false
	get_tree().paused = false
	_director.choose_greed()

func _on_dead() -> void:
	if _ended:
		return
	if "--ship-test" in OS.get_cmdline_user_args():
		return
	_ended = true
	RunState.mark("lost")
	MetaProgress.bank_from_run(int(RunState.essence * 0.25), false)
	EventBus.run_lost.emit()
	await get_tree().create_timer(0.9).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")

func _on_won() -> void:
	if _ended:
		return
	_ended = true
	await get_tree().create_timer(1.1).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")

func _on_extracted(_amt: int) -> void:
	if _ended:
		return
	_ended = true
	await get_tree().create_timer(0.6).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")

func _paint_bg(biome: int) -> void:
	for c in _bg.get_children():
		c.queue_free()
	var base := Color(0.04, 0.05, 0.07)
	match biome:
		1: base = Color(0.05, 0.04, 0.1)
		2: base = Color(0.08, 0.03, 0.04)
		3: base = Color(0.06, 0.02, 0.05)
	var floor_p := Polygon2D.new()
	floor_p.polygon = PackedVector2Array([Vector2(0,0), Vector2(1280,0), Vector2(1280,720), Vector2(0,720)])
	floor_p.color = base
	_bg.add_child(floor_p)
	for i in 5:
		var ring := Polygon2D.new()
		var r := 60.0 + float(i) * 55.0
		var pts := PackedVector2Array()
		for a in 40:
			pts.append(Vector2(640, 360) + Vector2.from_angle(TAU * float(a) / 40.0) * r)
		ring.polygon = pts
		ring.color = Color(0.2, 0.9, 0.5, 0.03 + float(i) * 0.01)
		_bg.add_child(ring)
