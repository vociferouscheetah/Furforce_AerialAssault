extends StaticBody3D

# Radius at which push-back begins (inside the hard wall)
@export var push_start_radius := 400.0
# Hard boundary radius — matches the CollisionShape3D sphere in arena.tscn
@export var arena_radius      := 500.0
# Maximum push strength (units/sec) applied at the hard wall
@export var push_strength     :=  50.0


## Returns a push-back force vector for an actor at [param actor_position].
## Add the result directly to the actor's velocity each physics frame.
##
## Example (in player_controller.gd or enemy_controller.gd):
##   velocity += arena_boundary.get_boundary_force(global_position)
func get_boundary_force(actor_position: Vector3) -> Vector3:
	var dist := actor_position.length()   # distance from world origin
	if dist > push_start_radius:
		var t: float = clamp(
			(dist - push_start_radius) / (arena_radius - push_start_radius),
			0.0, 1.0
		)
		# Quadratic ramp — gentle near push_start, strong near the wall
		return -actor_position.normalized() * push_strength * t * t
	return Vector3.ZERO
