class_name RunDirector
extends Node
## Drives biomes, waves, shop, apex, extract fork.

signal request_shop
signal request_extract_choice

const HOST_SCENE := preload("res://scenes/entities/host.tscn")
const BIOME_NAMES := ["Sewers", "Neon Sprawl", "Cathedral of Meat", "Apex Spire"]

@export var spawn_parent_path: NodePath
var _spawn: Node2D
var _phase: String = "intro" # intro|waves|clearwait|shop|apex|done
var _timer: float = 0.8
var _waves_left: int = 0
var _spawned_apex: bool = false

func _ready() -> void:
	_spawn = get_node(spawn_parent_path) as Node2D

func start() -> void:
	RunState.biome_index = 0
	_begin_biome(0)

func _process(delta: float) -> void:
	if not RunState.run_active:
		return
	match _phase:
		"intro", "between_waves":
			_timer -= delta
			if _timer <= 0.0:
				_spawn_wave()
		"clearwait":
			if RunState.hostiles_alive <= 0:
				_on_wave_clear()
		"apex_wait":
			if RunState.hostiles_alive <= 0 and _spawned_apex:
				_phase = "done"
				_win_apex()

func _begin_biome(idx: int) -> void:
	RunState.biome_index = idx
	RunState.biome_name = BIOME_NAMES[idx]
	RunState.wave_in_biome = 0
	_spawned_apex = false
	EventBus.biome_started.emit(idx, RunState.biome_name)
	if idx >= 3:
		_phase = "between_waves"
		_timer = 1.0
		_waves_left = 0 # special: apex only
		call_deferred("_spawn_apex")
		return
	_waves_left = 3 + idx
	_phase = "intro"
	_timer = 1.0

func _spawn_wave() -> void:
	if _waves_left <= 0:
		_biome_cleared()
		return
	_waves_left -= 1
	RunState.wave_in_biome += 1
	var table: Array[String] = HostCatalog.biome_table(RunState.biome_index)
	var count: int = 3 + RunState.wave_in_biome + RunState.biome_index
	for i in count:
		var id: String = table[i % table.size()]
		_spawn_host(id, i, count)
	_phase = "clearwait"

func _spawn_host(id: String, index: int, total: int) -> void:
	var h: Node2D = HOST_SCENE.instantiate() as Node2D
	h.global_position = _edge_point(index, total)
	_spawn.add_child(h)
	h.call("setup", id)

func _spawn_apex() -> void:
	_spawned_apex = true
	var h: Node2D = HOST_SCENE.instantiate() as Node2D
	h.global_position = Vector2(640, 200)
	_spawn.add_child(h)
	h.call("setup", "apex")
	EventBus.apex_spawned.emit()
	_phase = "apex_wait"

func _on_wave_clear() -> void:
	EventBus.floating_text.emit(Vector2(640, 200), "WAVE CLEAR", Color(0.6, 1.0, 0.8))
	if _waves_left <= 0:
		_biome_cleared()
	else:
		_phase = "between_waves"
		_timer = 1.2

func _biome_cleared() -> void:
	EventBus.biome_cleared.emit(RunState.biome_index)
	if RunState.biome_index >= 2:
		# After cathedral → extract choice then apex
		_phase = "shop"
		request_extract_choice.emit()
	else:
		_phase = "shop"
		request_shop.emit()

func continue_after_shop() -> void:
	_begin_biome(RunState.biome_index + 1)

func choose_extract() -> void:
	RunState.mark("extracted")
	MetaProgress.bank_from_run(RunState.essence, false)
	EventBus.run_extracted.emit(RunState.essence)

func choose_greed() -> void:
	_begin_biome(3)

func _win_apex() -> void:
	RunState.add_essence(50)
	RunState.mark("won")
	MetaProgress.bank_from_run(RunState.essence, true)
	EventBus.run_won.emit()
	AudioService.play_win()

func _edge_point(index: int, total: int) -> Vector2:
	var t := float(index + 1) / float(total + 1)
	match index % 4:
		0: return Vector2(lerpf(80, 1200, t), 70)
		1: return Vector2(1210, lerpf(70, 650, t))
		2: return Vector2(lerpf(80, 1200, t), 650)
		_: return Vector2(70, lerpf(70, 650, t))
