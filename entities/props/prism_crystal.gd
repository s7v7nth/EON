class_name PrismCrystal
extends Area2D
## Floor crystal from Prismatic Trap — melee near it splits into ray projectiles.
## No lifetime timer: removed by melee split or overflow (oldest explodes).

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")
const CRYSTAL_COLOR := Color(0.7, 0.45, 1.0, 0.85)
const RAY_COUNT := 8
const RAY_DAMAGE := 7.0

var owner_player: Node
var field: Object
var _spent: bool = false
var _visual: Polygon2D


func _ready() -> void:
	z_index = 6
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	add_to_group("prism_crystal")
	_ensure_visual()


func configure(player: Node, econ_field: Object = null, _life: float = -1.0) -> void:
	owner_player = player
	field = econ_field


func try_split_from_melee(origin: Vector2, radius: float = 70.0) -> bool:
	if _spent:
		return false
	if global_position.distance_to(origin) > radius:
		return false
	_split()
	return true


## Cap overflow: oldest crystal detonates into rays (same payoff as melee).
func force_explode() -> void:
	_split()


func _split() -> void:
	if _spent:
		return
	_spent = true
	var parent := get_parent()
	if parent == null:
		_expire()
		return
	var attack := AttackData.new()
	attack.damage = RAY_DAMAGE
	attack.projectile_speed = 520.0
	attack.projectile_lifetime = 0.55
	attack.returning = false
	attack.damage_type = GameplayEnums.DamageType.ELECTRICITY
	for i in RAY_COUNT:
		var dir := Vector2.from_angle(TAU * float(i) / float(RAY_COUNT))
		var proj := PROJECTILE_SCENE.instantiate() as Projectile
		proj.attack_data = attack
		proj.direction = dir
		proj.source = owner_player
		proj.tint = CRYSTAL_COLOR
		proj.collision_mask = (1 << 0) | (1 << 4)
		proj.max_mirror_bounces = 0
		parent.add_child(proj)
		proj.global_position = global_position + dir * 12.0
	CameraFx.flash(Color(0.75, 0.5, 1.0, 0.4), 0.08)
	HitVFX.spawn_prism_explode(parent, global_position, CRYSTAL_COLOR)
	SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, 60)
	_expire()


func _expire() -> void:
	if field != null and field.has_method("unregister_crystal"):
		field.call("unregister_crystal", self)
	queue_free()


func _ensure_visual() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	_visual.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(12, -4), Vector2(8, 14), Vector2(-8, 14), Vector2(-12, -4)
	])
	_visual.color = CRYSTAL_COLOR
	var tw := create_tween().set_loops()
	tw.tween_property(_visual, "scale", Vector2(1.08, 1.08), 0.4)
	tw.tween_property(_visual, "scale", Vector2.ONE, 0.4)
