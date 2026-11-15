extends Control

@onready var _title: Label = $Center/VBox/Title
@onready var _stats: Label = $Center/VBox/Stats
@onready var _again: Button = $Center/VBox/Again
@onready var _menu: Button = $Center/VBox/Menu

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	match RunState.outcome:
		"won":
			_title.text = "APEX CONSUMED"
			_title.modulate = Color(1.0, 0.45, 0.7)
		"extracted":
			_title.text = "EXTRACTED"
			_title.modulate = Color(0.5, 1.0, 0.75)
		_:
			_title.text = "WORM PASTE"
			_title.modulate = Color(1.0, 0.4, 0.4)
	_stats.text = "Essence banked path  ·  Run essence %d\nBest combo x%d  ·  Hosts ridden %d  ·  Kills %d\nMeta bank %d" % [
		RunState.essence, RunState.best_combo, RunState.hosts_ridden, RunState.kills, MetaProgress.banked_essence
	]
	_again.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")
	)
	_menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	var args := OS.get_cmdline_user_args()
	if "--autoplay" in args or "--ship-test" in args:
		await get_tree().create_timer(0.5).timeout
		var tex := get_viewport().get_texture()
		if tex:
			var img := tex.get_image()
			if img:
				img.save_png("user://hc-result-%s.png" % RunState.outcome)
				print("RESULT_CAPTURE: ", RunState.outcome)
		get_tree().quit(0 if RunState.outcome in ["won", "extracted"] else 1)
