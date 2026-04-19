extends CharacterBody3D

# --- Speed ---
@export var base_speed    := 30.0   # normal cruise
@export var boost_speed   := 80.0   # held boost
@export var brake_speed   :=  8.0   # held brake (near-stall)
@export var speed_lerp_weight := 3.0

# --- Rotation rates (radians / sec) ---
@export var pitch_speed := 1.8
@export var yaw_speed   := 1.2
@export var roll_speed  := 2.5

# --- Physics feel ---
@export var gravity_pull := 6.0    # downward pull when stalling
@export var stall_speed  := 12.0   # below this, gravity kicks in

# --- Arena boundary (mirrors arena_boundary.gd defaults) ---
@export var arena_push_start    := 400.0
@export var arena_radius        := 500.0
@export var arena_push_strength :=  60.0

# --- State (read by chase_camera.gd) ---
var current_speed := 30.0
var is_boosting   := false

@onready var _health: HealthComponent = get_node_or_null("HealthComponent")


func _ready() -> void:
	if _health:
		_health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_handle_rotation(delta)
	_handle_speed(delta)
	_build_velocity()
	move_and_slide()


# ---------------------------------------------------------------------------
# Rotation
# ---------------------------------------------------------------------------
func _handle_rotation(delta: float) -> void:
	var pitch := Input.get_action_strength("pitch_up")   - Input.get_action_strength("pitch_down")
	var yaw   := Input.get_action_strength("yaw_left")   - Input.get_action_strength("yaw_right")
	var roll  := Input.get_action_strength("roll_left")  - Input.get_action_strength("roll_right")

	# Apply pitch around local X
	if pitch != 0.0:
		transform.basis = transform.basis.rotated(transform.basis.x, pitch * pitch_speed * delta)

	# Apply yaw around local Y, then auto-bank the model into the turn
	if yaw != 0.0:
		transform.basis = transform.basis.rotated(transform.basis.y,  yaw * yaw_speed  * delta)
		transform.basis = transform.basis.rotated(transform.basis.z, -yaw * 0.6        * delta)

	# Apply manual roll around local Z
	if roll != 0.0:
		transform.basis = transform.basis.rotated(transform.basis.z, roll * roll_speed * delta)

	# Keep the basis orthonormal (prevent drift / skewing over time)
	transform.basis = transform.basis.orthonormalized()


# ---------------------------------------------------------------------------
# Speed
# ---------------------------------------------------------------------------
func _handle_speed(delta: float) -> void:
	is_boosting      = Input.is_action_pressed("boost")
	var braking      := Input.is_action_pressed("brake")

	var target := boost_speed if is_boosting else (brake_speed if braking else base_speed)
	current_speed = lerpf(current_speed, target, speed_lerp_weight * delta)


# ---------------------------------------------------------------------------
# Velocity assembly
# ---------------------------------------------------------------------------
func _build_velocity() -> void:
	# Always fly forward along local -Z
	velocity = -transform.basis.z * current_speed

	# Mild gravity when close to stall
	if current_speed < stall_speed:
		var stall_factor := 1.0 - (current_speed / stall_speed)
		velocity += Vector3.DOWN * gravity_pull * stall_factor

	# Soft arena push-back
	velocity += _get_boundary_force(global_position)


# ---------------------------------------------------------------------------
# Arena boundary (self-contained so it works before arena is wired up)
# ---------------------------------------------------------------------------
## Called by enemy bullets when they hit the player's HitboxArea
func take_damage(amount: float) -> void:
	if _health:
		_health.take_damage(amount)


func _on_died() -> void:
	# Phase 3: reset health and print message — full death sequence comes later
	print("Player destroyed! Respawning...")
	if _health:
		_health.heal(_health.max_health)


func _get_boundary_force(pos: Vector3) -> Vector3:
	var dist := pos.length()
	if dist > arena_push_start:
		var t: float = clamp(
			(dist - arena_push_start) / (arena_radius - arena_push_start),
			0.0, 1.0
		)
		return -pos.normalized() * arena_push_strength * t * t
	return Vector3.ZERO
