class_name EffectEchoShade
extends "res://systems/upgrades/upgrade_effect.gd"
## Synthetic craft: perfect dodge leaves a short-lived holographic Energy Mirror behind the attacker.

@export var mirror_lifetime: float = 2.0


func on_perfect_dodge(host: Node, source: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("spawn_echo_shade"):
		economy.call("spawn_echo_shade", source, mirror_lifetime)
