extends Node
## --autoplay [--force-lose]

var _t: float = 0.0
var _held: Dictionary = {}
var _shot: bool = false

func _ready() -> void:
	if "--autoplay" not in OS.get_cmdline_user_args():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("AUTOPLAY: host-cascade")

func _process(delta: float) -> void:
	_t += delta
	_release()
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# Aim toward nearest host/hostile
	var target := _nearest(["host", "hostile"], p as Node2D)
	if target != Vector2.ZERO:
		# fake mouse by moving toward and leaping
		_hold_toward((p as Node2D).global_position, target)
	else:
		_hold(["move_right", "move_down", "move_left", "move_up"][int(_t * 1.2) % 4])

	if fmod(_t, 0.5) < delta:
		_tap("leap")
	if fmod(_t, 0.35) < delta:
		_tap("attack")
	if fmod(_t, 2.5) < delta and not RunState.in_worm:
		_tap("eject")

	if _t > 2.5 and not _shot:
		_shot = true
		await _cap("arena-combat")

	if "--force-lose" in OS.get_cmdline_user_args() and _t > 4.0:
		EventBus.player_died.emit()

	if _t > 18.0:
		print("AUTOPLAY: timeout essence=", RunState.essence, " combo=", RunState.best_combo, " biome=", RunState.biome_index)
		# Try to skip shop/extract if visible
		_try_ui_skip()
		if _t > 22.0:
			get_tree().quit(0)

func _try_ui_skip() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.get_node_or_null("ShopOverlay") and scene.get_node("ShopOverlay").visible:
		if scene.has_method("close_shop_and_continue"):
			scene.call("close_shop_and_continue")
	if scene.get_node_or_null("ExtractOverlay") and scene.get_node("ExtractOverlay").visible:
		if scene.has_method("extract_now"):
			scene.call("extract_now")

func _nearest(groups: Array, from: Node2D) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for g in groups:
		for n in get_tree().get_nodes_in_group(str(g)):
			if n == from or not is_instance_valid(n):
				continue
			if n is Node2D:
				var d := from.global_position.distance_squared_to((n as Node2D).global_position)
				if d < best_d:
					best_d = d
					best = (n as Node2D).global_position
	return best

func _hold_toward(from: Vector2, to: Vector2) -> void:
	var d := to - from
	if absf(d.x) >= absf(d.y):
		_hold("move_right" if d.x > 0 else "move_left")
	else:
		_hold("move_down" if d.y > 0 else "move_up")

func _hold(a: String) -> void:
	if _held.get(a, false):
		return
	Input.action_press(a)
	_held[a] = true

func _release() -> void:
	for a in _held.keys():
		Input.action_release(a)
	_held.clear()

func _tap(a: String) -> void:
	Input.action_press(a)
	await get_tree().process_frame
	Input.action_release(a)

func _cap(label: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("user://%s.png" % label)
		print("AUTOPLAY: shot ", label)
