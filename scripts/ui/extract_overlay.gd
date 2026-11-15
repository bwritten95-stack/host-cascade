extends CanvasLayer

@onready var _extract: Button = $Root/Panel/VBox/Extract
@onready var _greed: Button = $Root/Panel/VBox/Greed
@onready var _info: Label = $Root/Panel/VBox/Info

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visibility_changed.connect(_on_vis)
	_extract.pressed.connect(func() -> void:
		var arena := get_tree().current_scene
		if arena and arena.has_method("extract_now"):
			arena.call("extract_now")
	)
	_greed.pressed.connect(func() -> void:
		var arena := get_tree().current_scene
		if arena and arena.has_method("greed_apex"):
			arena.call("greed_apex")
	)

func _on_vis() -> void:
	if visible:
		_info.text = "Bank %d essence safely — or greed for the Apex Host." % RunState.essence
