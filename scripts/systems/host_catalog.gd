class_name HostCatalog
extends RefCounted

static func make(id: String) -> HostDef:
	var d := HostDef.new()
	match id:
		"grunt":
			d.id = "grunt"; d.display_name = "Grunt"; d.tier = 1
			d.max_hp = 4; d.speed = 150.0; d.damage = 1; d.essence = 8
			d.color = Color(0.95, 0.4, 0.45); d.attack_kind = "melee"
		"spitter":
			d.id = "spitter"; d.display_name = "Spitter"; d.tier = 2
			d.max_hp = 3; d.speed = 120.0; d.damage = 1; d.attack_cooldown = 0.9
			d.essence = 12; d.color = Color(0.55, 0.75, 1.0); d.attack_kind = "spit"
		"tank":
			d.id = "tank"; d.display_name = "Tank"; d.tier = 3
			d.max_hp = 10; d.speed = 90.0; d.damage = 2; d.attack_cooldown = 1.1
			d.essence = 18; d.color = Color(1.0, 0.7, 0.25); d.radius = 20.0
			d.attack_kind = "slam"
		"stalker":
			d.id = "stalker"; d.display_name = "Stalker"; d.tier = 3
			d.max_hp = 5; d.speed = 200.0; d.damage = 1; d.attack_cooldown = 0.7
			d.essence = 16; d.color = Color(0.7, 0.4, 1.0); d.attack_kind = "dash"
		"brood":
			d.id = "brood"; d.display_name = "Brood"; d.tier = 2
			d.max_hp = 6; d.speed = 130.0; d.damage = 1; d.essence = 14
			d.color = Color(0.45, 1.0, 0.55); d.attack_kind = "melee"
		"apex":
			d.id = "apex"; d.display_name = "Apex Host"; d.tier = 5
			d.max_hp = 60; d.speed = 110.0; d.damage = 2; d.attack_cooldown = 0.8
			d.essence = 120; d.color = Color(1.0, 0.2, 0.55); d.radius = 28.0
			d.attack_kind = "apex"
		_:
			d.id = "grunt"; d.display_name = "Grunt"
	return d

static func biome_table(biome: int) -> Array[String]:
	match biome:
		0:
			return ["grunt", "grunt", "spitter", "grunt"]
		1:
			return ["grunt", "spitter", "spitter", "tank", "stalker"]
		2:
			return ["spitter", "tank", "stalker", "brood", "tank"]
		_:
			return ["apex"]
