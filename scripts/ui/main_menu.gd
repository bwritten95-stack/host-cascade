extends Control

@onready var _play: Button = $Center/VBox/Play
@onready var _meta: Button = $Center/VBox/Meta
@onready var _quit: Button = $Center/VBox/Quit
@onready var _meta_panel: Control = $MetaPanel
@onready var _meta_list: VBoxContainer = $MetaPanel/Panel/VBox/List
@onready var _meta_close: Button = $MetaPanel/Panel/VBox/Close
@onready var _bank: Label = $Center/VBox/Bank
@onready var _decor: Node2D = $Decor

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_play.pressed.connect(func() -> void:
		AudioService.play_ui()
		get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")
	)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_meta.pressed.connect(_open_meta)
	_meta_close.pressed.connect(func() -> void: _meta_panel.visible = false)
	_meta_panel.visible = false
	_bank.text = "Banked essence %d  ·  Runs %d  ·  Apex kills %d" % [
		MetaProgress.banked_essence, MetaProgress.runs, MetaProgress.apex_kills
	]
	_spawn_decor()
	if "--autoplay" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.8).timeout
		await _capture("menu")
		get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

func _spawn_decor() -> void:
	for i in 18:
		var p := Polygon2D.new()
		var s := randf_range(5.0, 16.0)
		p.polygon = PackedVector2Array([Vector2(0,-s), Vector2(s*0.7,0), Vector2(0,s*0.6), Vector2(-s*0.7,0)])
		p.color = Color(0.3, 1.0, 0.6, randf_range(0.06, 0.18))
		p.position = Vector2(randf_range(40, 1240), randf_range(40, 680))
		p.set_meta("spin", randf_range(-0.8, 0.8))
		_decor.add_child(p)

func _process(delta: float) -> void:
	for c in _decor.get_children():
		c.rotation += delta * float(c.get_meta("spin", 0.3))

func _open_meta() -> void:
	AudioService.play_ui()
	_meta_panel.visible = true
	for c in _meta_list.get_children():
		c.queue_free()
	for id in MetaProgress.CATALOG.keys():
		var info: Dictionary = MetaProgress.CATALOG[id]
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.text = "%s — %s" % [info["name"], info["desc"]]
		var btn := Button.new()
		var owned: bool = str(id) in MetaProgress.unlocked
		btn.text = "Owned" if owned else "Unlock %d" % int(info["cost"])
		btn.disabled = owned or int(info["cost"]) <= 0
		var unlock_id: String = str(id)
		btn.pressed.connect(func() -> void:
			if MetaProgress.try_unlock(unlock_id):
				AudioService.play_ui()
				_open_meta()
				_bank.text = "Banked essence %d" % MetaProgress.banked_essence
		)
		row.add_child(lab)
		row.add_child(btn)
		_meta_list.add_child(row)

func _capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img:
		img.save_png("user://%s.png" % label)
		print("MENU_CAPTURE: ", label)
