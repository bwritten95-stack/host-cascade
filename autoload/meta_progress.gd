extends Node
## Persists between runs — unlocks that tempt “one more.”

const PATH := "user://host_cascade_meta.cfg"

var banked_essence: int = 0
var runs: int = 0
var apex_kills: int = 0
var unlocked: Array[String] = ["grip"]
var selected_loadout: Array[String] = []

const CATALOG := {
	"grip": {"name": "Rift Grip", "desc": "+10% possess range", "cost": 0},
	"lung": {"name": "Second Lung", "desc": "+0.5s worm timer", "cost": 40},
	"fang": {"name": "Echo Fang", "desc": "+1 attack damage", "cost": 55},
	"greed": {"name": "Greedy Vein", "desc": "+20% essence", "cost": 70},
	"shock": {"name": "Eject Shock", "desc": "Eject damages nearby foes", "cost": 90},
	"chain": {"name": "Chain Instinct", "desc": "Combo starts at x2 after leap", "cost": 110},
	"shell": {"name": "Borrowed Shell", "desc": "Enter hosts at +20% HP", "cost": 130},
	"apex_key": {"name": "Apex Key", "desc": "Apex bleeds essence faster", "cost": 160},
}

func _ready() -> void:
	load_meta()

func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		unlocked = ["grip"]
		return
	banked_essence = int(cfg.get_value("meta", "banked", 0))
	runs = int(cfg.get_value("meta", "runs", 0))
	apex_kills = int(cfg.get_value("meta", "apex", 0))
	var u: Variant = cfg.get_value("meta", "unlocked", ["grip"])
	unlocked.clear()
	for x in u:
		unlocked.append(str(x))
	if not ("grip" in unlocked):
		unlocked.append("grip")

func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "banked", banked_essence)
	cfg.set_value("meta", "runs", runs)
	cfg.set_value("meta", "apex", apex_kills)
	cfg.set_value("meta", "unlocked", unlocked)
	cfg.save(PATH)

func worm_bonus() -> float:
	return 0.6 if "lung" in unlocked else 0.0

func starting_mutations() -> Array[String]:
	var out: Array[String] = []
	for id in unlocked:
		if id != "" and id in CATALOG:
			out.append(id)
	return out

func try_unlock(id: String) -> bool:
	if id in unlocked:
		return false
	if not CATALOG.has(id):
		return false
	var cost: int = int(CATALOG[id]["cost"])
	if banked_essence < cost:
		return false
	banked_essence -= cost
	unlocked.append(id)
	save_meta()
	return true

func bank_from_run(amount: int, won_apex: bool) -> void:
	var gain := amount
	if "greed" in unlocked:
		gain = int(gain * 1.2)
	banked_essence += gain
	runs += 1
	if won_apex:
		apex_kills += 1
	save_meta()
