extends Node
## Per-run state. Reset at run start.

var run_active: bool = false
var outcome: String = "" # won | lost | extracted | ""

var essence: int = 0
var combo: int = 0
var best_combo: int = 0
var mult: float = 1.0
var hosts_ridden: int = 0
var kills: int = 0

var biome_index: int = 0
var biome_name: String = "Sewers"
var wave_in_biome: int = 0
var hostiles_alive: int = 0

var worm_time: float = 0.0
var worm_time_max: float = 2.4
var in_worm: bool = true
var possessed_tier: int = 0

var mutations: Array[String] = [] # ids active this run

func reset() -> void:
	run_active = true
	outcome = ""
	essence = 0
	combo = 0
	best_combo = 0
	mult = 1.0
	hosts_ridden = 0
	kills = 0
	biome_index = 0
	biome_name = "Sewers"
	wave_in_biome = 0
	hostiles_alive = 0
	worm_time = 0.0
	worm_time_max = 3.2 + MetaProgress.worm_bonus()
	in_worm = true
	possessed_tier = 0
	mutations = MetaProgress.starting_mutations()

func add_essence(base: int) -> void:
	var gain := int(round(float(base) * mult))
	essence += gain
	EventBus.essence_gained.emit(gain, essence)

func bump_combo() -> void:
	combo += 1
	best_combo = max(best_combo, combo)
	mult = 1.0 + float(mini(combo, 20)) * 0.15
	EventBus.combo_changed.emit(combo, mult)
	AudioService.play_combo(combo)
	if combo == 5 or combo == 10 or combo == 15:
		EventBus.camera_shake.emit(7.0, 0.12)
		EventBus.floating_text.emit(Vector2(640, 260), "COMBO x%d" % combo, Color(1.0, 0.85, 0.35))
		EventBus.hitstop.emit(0.05)

func break_combo() -> void:
	combo = 0
	mult = 1.0
	EventBus.combo_changed.emit(combo, mult)

func has_mutation(id: String) -> bool:
	return id in mutations

func mark(end: String) -> void:
	run_active = false
	outcome = end
