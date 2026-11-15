extends CanvasLayer
## Between-biome draft: pick one mutation for THIS run (addictive power spike).

const OFFERS := [
	["lung", "fang", "greed"],
	["shock", "chain", "shell"],
	["apex_key", "fang", "lung"],
]

@onready var _title: Label = $Root/Panel/VBox/Title
@onready var _box: VBoxContainer = $Root/Panel/VBox/Offers
@onready var _skip: Button = $Root/Panel/VBox/Skip
@onready var _bank: Label = $Root/Panel/VBox/Bank

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_skip.pressed.connect(_finish)

func open_shop() -> void:
	for c in _box.get_children():
		c.queue_free()
	_title.text = "MUTATION VAULT — pick one for this run"
	_bank.text = "Essence %d  ·  Banked meta %d" % [RunState.essence, MetaProgress.banked_essence]
	var row: Array = OFFERS[mini(RunState.biome_index, OFFERS.size() - 1)]
	for id in row:
		_add_offer(str(id))

func _add_offer(id: String) -> void:
	if not MetaProgress.CATALOG.has(id):
		return
	var info: Dictionary = MetaProgress.CATALOG[id]
	var btn := Button.new()
	btn.text = "%s — %s" % [str(info["name"]), str(info["desc"])]
	var already: bool = id in RunState.mutations
	if already:
		btn.text += " [ACTIVE]"
		btn.disabled = true
	btn.pressed.connect(func() -> void:
		if id not in RunState.mutations:
			RunState.mutations.append(id)
		# Also unlock permanently if affordable from banked
		var unlocked_already: bool = id in MetaProgress.unlocked
		if not unlocked_already and MetaProgress.banked_essence >= int(info["cost"]):
			MetaProgress.try_unlock(id)
		AudioService.play_ui()
		EventBus.floating_text.emit(Vector2(640, 280), str(info["name"]).to_upper(), Color(0.5, 1.0, 0.75))
		_finish()
	)
	_box.add_child(btn)

func _finish() -> void:
	visible = false
	var arena := get_tree().current_scene
	if arena and arena.has_method("close_shop_and_continue"):
		arena.call("close_shop_and_continue")
