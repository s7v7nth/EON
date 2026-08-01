extends Node
## Hades-style isometric helpers for 2D floor-plane gameplay.

## Screen-vertical movement scale — creates the slanted-floor feel.
const Y_SCALE: float = 0.7


## Converts a unit input/direction into world velocity with iso Y compression.
func apply_velocity(direction: Vector2, speed: float) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	var velocity := direction.normalized() * speed
	velocity.y *= Y_SCALE
	return velocity
