extends CanvasLayer

@onready var _hp: Label = $Root/Top/HP
@onready var _essence: Label = $Root/Top/Essence
@onready var _combo: Label = $Root/Top/Combo
@onready var _biome: Label = $Root/Top/Biome
@onready var _worm: ProgressBar = $Root/WormBar
@onready var _hint: Label = $Root/Hint
@onready var _banner: Label = $Root/Banner

func _ready() -> void:
	EventBus.biome_started.connect(func(_i: int, n: String) -> void:
		_flash_banner(n.to_upper())
	)
	EventBus.apex_spawned.connect(func() -> void: _flash_banner("APEX HOST"))
	EventBus.worm_timer_changed.connect(_on_worm)
	_hint.text = "WASD move · Mouse aim · Click/J attack · Space leap/possess · F/E eject · Esc pause"
	_worm.visible = false
	_banner.modulate.a = 0.0

func _process(_d: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and not RunState.in_worm and p.get("host_def") != null:
		var def: HostDef = p.get("host_def") as HostDef
		_hp.text = "SHELL  %s  %d/%d" % [def.display_name, int(p.get("host_hp")), int(p.get("host_max_hp"))]
	elif RunState.in_worm:
		_hp.text = "WORM FORM — leap into a body!"
	else:
		_hp.text = "…"
	_essence.text = "Essence %d" % RunState.essence
	_combo.text = ("COMBO x%d  ×%.1f" % [RunState.combo, RunState.mult]) if RunState.combo > 0 else "Combo —"
	_biome.text = "%s  W%d" % [RunState.biome_name, RunState.wave_in_biome]
	_worm.visible = RunState.in_worm and RunState.run_active

func _on_worm(remaining: float, max_t: float) -> void:
	_worm.max_value = max_t
	_worm.value = remaining
	_worm.modulate = Color(0.4, 1.0, 0.7).lerp(Color(1.0, 0.3, 0.3), 1.0 - clampf(remaining / maxf(max_t, 0.01), 0.0, 1.0))

func _flash_banner(t: String) -> void:
	_banner.text = t
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.45)
