extends Node

signal possessed(host: Node2D)
signal ejected(world_pos: Vector2)
signal leap_started(from_pos: Vector2, dir: Vector2)
signal leap_hit(host: Node2D)
signal leap_missed
signal host_killed(world_pos: Vector2, essence: int, by_player: bool)
signal combo_changed(combo: int, mult: float)
signal essence_gained(amount: int, total: int)
signal worm_timer_changed(remaining: float, max_time: float)
signal player_died
signal biome_started(index: int, name: String)
signal biome_cleared(index: int)
signal shop_opened
signal shop_closed
signal apex_spawned
signal run_extracted(essence_banked: int)
signal run_won
signal run_lost
signal camera_shake(amount: float, duration: float)
signal hitstop(duration: float)
signal floating_text(world_pos: Vector2, text: String, color: Color)
