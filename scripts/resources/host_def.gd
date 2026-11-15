class_name HostDef
extends Resource

@export var id: String = "grunt"
@export var display_name: String = "Grunt"
@export var tier: int = 1
@export var max_hp: int = 4
@export var speed: float = 140.0
@export var damage: int = 1
@export var attack_cooldown: float = 0.55
@export var essence: int = 8
@export var color: Color = Color(0.9, 0.35, 0.4)
@export var radius: float = 14.0
@export var attack_kind: String = "melee" # melee | spit | slam | dash | apex
