extends Node

const BUS_SFX := "SFX"
var _players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if AudioServer.get_bus_index(BUS_SFX) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, "Master")
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	SettingsStore.apply()

func play_possess() -> void:
	_tone(220.0, 0.08, 0.28, "up")
	_tone(440.0, 0.1, 0.2, "up")

func play_eject() -> void:
	_tone(300.0, 0.07, 0.22, "down")

func play_leap() -> void:
	_noise(0.06, 0.25)
	_tone(660.0, 0.05, 0.15, "up")

func play_hit() -> void:
	_tone(140.0, 0.05, 0.25, "down")

func play_kill() -> void:
	_tone(180.0, 0.08, 0.2, "down")
	_tone(520.0, 0.1, 0.18, "up")

func play_combo(level: int) -> void:
	_tone(400.0 + float(level) * 40.0, 0.06, 0.18, "up")

func play_ui() -> void:
	_tone(700.0, 0.04, 0.12, "none")

func play_die() -> void:
	_tone(90.0, 0.25, 0.35, "down")

func play_win() -> void:
	_tone(523.0, 0.1, 0.2, "none")
	_tone(659.0, 0.1, 0.2, "none")
	_tone(784.0, 0.16, 0.25, "none")

func _acquire() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _tone(freq: float, dur: float, vol: float, slide: String) -> void:
	var player := _acquire()
	var rate := 22050.0
	var frames := int(dur * rate)
	var data := PackedVector2Array()
	data.resize(frames)
	for i in frames:
		var t := float(i) / rate
		var env := pow(1.0 - float(i) / float(frames), 1.5)
		var f := freq
		if slide == "up":
			f = lerpf(freq, freq * 1.7, float(i) / float(frames))
		elif slide == "down":
			f = lerpf(freq, freq * 0.4, float(i) / float(frames))
		var s := sin(TAU * f * t) * vol * env
		data[i] = Vector2(s, s)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = int(rate)
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = _pcm(data)
	player.stream = stream
	player.play()

func _noise(dur: float, vol: float) -> void:
	var player := _acquire()
	var rate := 22050.0
	var frames := int(dur * rate)
	var data := PackedVector2Array()
	data.resize(frames)
	var lp := 0.0
	for i in frames:
		var env := pow(1.0 - float(i) / float(frames), 2.0)
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.35)
		var s := lp * vol * env
		data[i] = Vector2(s, s)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = int(rate)
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = _pcm(data)
	player.stream = stream
	player.play()

func _pcm(samples: PackedVector2Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 4)
	var i := 0
	for s in samples:
		var l := int(clampf(s.x, -1.0, 1.0) * 32767.0)
		var r := int(clampf(s.y, -1.0, 1.0) * 32767.0)
		bytes[i] = l & 0xFF
		bytes[i + 1] = (l >> 8) & 0xFF
		bytes[i + 2] = r & 0xFF
		bytes[i + 3] = (r >> 8) & 0xFF
		i += 4
	return bytes
