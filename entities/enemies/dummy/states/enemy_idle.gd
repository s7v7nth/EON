extends State
## Wait until a player enters DetectionArea.

@onready var enemy: EnemyDummy = owner as EnemyDummy


func physics_update(_delta: float) -> void:
	enemy.stop_movement()
	if enemy.is_stunned() or enemy.is_flinching():
		return
	if enemy.target != null:
		transition_to(&"Chase")
