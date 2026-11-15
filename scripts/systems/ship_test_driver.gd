extends Node
## Full-run verifier: --autoplay --ship-test
## Auto-clears waves, picks shop, greeds Apex, forces win, captures media.

var _t: float = 0.0
var _phase_shot: Dictionary = {}
var _held: Dictionary = {}

func _ready() -> void:
	if "--ship-test" not in OS.get_cmdline_user_args():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SHIP_TEST: enabled")
	RunState.worm_time_max = 99.0
	call_deferred("_arm")

func _arm() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.set("_invuln_ship", true)

func _process(delta: float) -> void:
	_t += delta
	_release()
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# Soft invuln + refill worm
	RunState.worm_time = 0.0
	if p.get("mode") == 0: # WORM
		p.set("_alive", true)
		p.visible = true

	var target := _nearest(p as Node2D)
	if target != Vector2.ZERO:
		_hold_toward((p as Node2D).global_position, target)
		# Warp mouse toward target for aim
		Input.warp_mouse(get_viewport().get_canvas_transform() * target)
	else:
		_hold(["move_right", "move_down", "move_left", "move_up"][int(_t) % 4])

	if fmod(_t, 0.35) < delta:
		_tap("leap")
	if fmod(_t, 0.28) < delta:
		_tap("attack")

	# Accelerate clears: periodically delete hostiles when stuck
	if fmod(_t, 2.5) < delta and RunState.hostiles_alive > 0 and RunState.biome_index < 3:
		_damage_all_hostiles(3)

	_handle_overlays()
	_shots()

	# Apex force kill after shot
	if RunState.biome_index >= 3 and _t > 8.0 and RunState.hostiles_alive > 0:
		_damage_all_hostiles(20)

	if _t > 55.0:
		print("SHIP_TEST: timeout outcome=", RunState.outcome, " biome=", RunState.biome_index, " essence=", RunState.essence)
		get_tree().quit(1)

var _shop_handled: bool = false
var _extract_handled: bool = false

func _handle_overlays() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var shop := scene.get_node_or_null("ShopOverlay")
	if shop and shop.visible and not _shop_handled:
		_shop_handled = true
		await _cap("hc-shop")
		var offers := shop.get_node_or_null("Root/Panel/VBox/Offers")
		if offers and offers.get_child_count() > 0:
			var btn: Button = offers.get_child(0) as Button
			if btn and not btn.disabled:
				btn.set_pressed(true)
				btn.pressed.emit()
				_shop_handled = false # next biome shop
				return
		if scene.has_method("close_shop_and_continue"):
			scene.call("close_shop_and_continue")
		_shop_handled = false
		return

	var extract := scene.get_node_or_null("ExtractOverlay")
	if extract and extract.visible and not _extract_handled:
		_extract_handled = true
		await _cap("hc-extract")
		print("SHIP_TEST: greed → Apex")
		if scene.has_method("greed_apex"):
			scene.call("greed_apex")


func _shots() -> void:
	if RunState.biome_index == 0 and RunState.wave_in_biome >= 1 and not _phase_shot.get("b0", false):
		_phase_shot["b0"] = true
		await _cap("hc-biome1")
	if RunState.biome_index == 1 and not _phase_shot.get("b1", false):
		_phase_shot["b1"] = true
		await _cap("hc-biome2")
	if RunState.biome_index == 2 and not _phase_shot.get("b2", false):
		_phase_shot["b2"] = true
		await _cap("hc-biome3")
	if RunState.biome_index >= 3 and not _phase_shot.get("apex", false):
		_phase_shot["apex"] = true
		await get_tree().create_timer(0.6).timeout
		await _cap("hc-apex")

func _damage_all_hostiles(amount: int) -> void:
	for n in get_tree().get_nodes_in_group("hostile"):
		if is_instance_valid(n) and n.has_method("take_damage"):
			n.call("take_damage", amount, true)

func _nearest(from: Node2D) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for n in get_tree().get_nodes_in_group("host"):
		if not is_instance_valid(n) or n == from:
			continue
		if n.get("possessed") == true or n.get("alive") == false:
			continue
		var d := from.global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = (n as Node2D).global_position
	if best == Vector2.ZERO:
		for n in get_tree().get_nodes_in_group("hostile"):
			if not is_instance_valid(n) or not (n is Node2D):
				continue
			var d2 := from.global_position.distance_squared_to((n as Node2D).global_position)
			if d2 < best_d:
				best_d = d2
				best = (n as Node2D).global_position
	return best

func _hold_toward(from: Vector2, to: Vector2) -> void:
	var d := to - from
	if absf(d.x) >= absf(d.y):
		_hold("move_right" if d.x > 0.0 else "move_left")
	else:
		_hold("move_down" if d.y > 0.0 else "move_up")

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
	await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img:
		img.save_png("user://%s.png" % label)
		print("SHIP_TEST: shot ", label)
