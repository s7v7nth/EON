class_name EffectFocusLens
extends "res://systems/upgrades/upgrade_effect.gd"
## Perfect parry also deploys a Focus Lens that amplifies blades ×2.5.


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("enable_focus_lens"):
		economy.call("enable_focus_lens")


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null:
		economy.set("spawn_lens_on_parry", false)
