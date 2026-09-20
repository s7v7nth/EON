class_name RunRng
extends RefCounted
## Seeded streams so map / spawn / loot stay reproducible without sharing VFX noise.

var seed_value: int = 0
var map: RandomNumberGenerator
var spawn: RandomNumberGenerator
var loot: RandomNumberGenerator


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


func reseed(p_seed: int) -> void:
	seed_value = p_seed
	map = RandomNumberGenerator.new()
	spawn = RandomNumberGenerator.new()
	loot = RandomNumberGenerator.new()
	map.seed = _derive(p_seed, 1)
	spawn.seed = _derive(p_seed, 2)
	loot.seed = _derive(p_seed, 3)


static func _derive(base: int, stream: int) -> int:
	## SplitMix64-ish mix so streams diverge from one master seed.
	var z := (base + stream * 0x9E3779B9) & 0xFFFFFFFF
	z = ((z ^ (z >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	z = ((z ^ (z >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	return int(z ^ (z >> 16))
