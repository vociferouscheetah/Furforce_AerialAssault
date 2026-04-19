extends Node3D

var drift_direction   := Vector3.RIGHT
var drift_speed       := 2.0
var wobble_amplitude  := 0.4
var wobble_speed      := 0.3
var arena_radius      := 450.0
var steer_radius      := 350.0   # start steering back inward at this distance
var _time_offset      := 0.0


func _process(delta: float) -> void:
	# Drift in current direction
	position += drift_direction * drift_speed * delta

	# Gentle vertical sine wobble
	var t := (Time.get_ticks_msec() * 0.001 + _time_offset) * wobble_speed
	position.y += sin(t) * wobble_amplitude * delta

	# Gradually steer back toward the arena centre instead of teleporting
	var dist := position.length()
	if dist > steer_radius:
		var inward    := -position.normalized()
		var t_steer: float = clamp(
			(dist - steer_radius) / (arena_radius - steer_radius),
			0.0, 1.0
		)
		drift_direction = drift_direction.lerp(inward, t_steer * 0.04).normalized()
