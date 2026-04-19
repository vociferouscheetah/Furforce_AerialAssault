extends CharacterBody3D

enum State { PATROL, PURSUE, ATTACK }

# --- Movement ---
@export var patrol_speed  := 20.0
@export var pursue_speed  := 38.0
@export var turn_speed_patrol  := 1.5
@export var turn_speed_pursue  := 2.8

# --- Combat ---
@export var bullet_scene: PackedScene
@export var attack_range        := 120.0
@export var attack_dot          :=  0.95
@export var fire_rate           :=  0.9
@export var min_pursue_distance :=  28.0  # back off if closer than this
@export var waypoint_reach_distance := 20.0

# --- Barrel roll ---
@export var roll_speed          :=  4.0   # radians/sec during a roll
@export var roll_duration       :=  1.0   # seconds per roll
@export var roll_interval_min   :=  3.0   # min seconds between rolls
@export var roll_interval_max   :=  8.0   # max seconds between rolls

# --- Arena boundary ---
@export var arena_push_start    := 400.0
@export var arena_radius        := 500.0
@export var arena_push_strength :=  60.0

var _state          := State.PATROL
var _patrol_target  := Vector3.ZERO
var _player: Node3D = null
var _can_fire       := true
var _health: HealthComponent

var _rolling        := false
var _roll_direction := 1.0

@onready var _gun_marker: Marker3D = $EnemyModel/GunMarker


func _ready() -> void:
	_patrol_target = _random_patrol_point()

	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health:
		_health.died.connect(_on_died)

	var zone := get_node_or_null("DetectionZone")
	if zone:
		zone.body_entered.connect(_on_body_entered)
		zone.body_exited.connect(_on_body_exited)

	# Kick off the first barrel roll timer
	_schedule_next_roll()


func _physics_process(delta: float) -> void:
	match _state:
		State.PATROL:
			_do_patrol(delta)
		State.PURSUE:
			_do_pursue(delta)
			_check_attack_transition()
		State.ATTACK:
			_do_pursue(delta)
			_check_attack_transition()
			_try_fire()

	# Apply barrel roll rotation on top of movement
	if _rolling:
		transform.basis = transform.basis.rotated(
			transform.basis.z, _roll_direction * roll_speed * delta
		)
		transform.basis = transform.basis.orthonormalized()

	velocity += _get_boundary_force(global_position)
	move_and_slide()


# ---------------------------------------------------------------------------
# States
# ---------------------------------------------------------------------------
func _do_patrol(delta: float) -> void:
	if global_position.distance_to(_patrol_target) < waypoint_reach_distance:
		_patrol_target = _random_patrol_point()

	_rotate_toward(_patrol_target, turn_speed_patrol, delta)
	velocity = -transform.basis.z * patrol_speed


func _do_pursue(delta: float) -> void:
	if not is_instance_valid(_player):
		_state = State.PATROL
		return

	var dist := global_position.distance_to(_player.global_position)

	if dist < min_pursue_distance:
		# Too close — break away to avoid clipping
		velocity = (global_position - _player.global_position).normalized() * patrol_speed
		return

	_rotate_toward(_player.global_position, turn_speed_pursue, delta)
	velocity = -transform.basis.z * pursue_speed


func _check_attack_transition() -> void:
	if not is_instance_valid(_player):
		return

	var to_player := _player.global_position - global_position
	var dist      := to_player.length()
	var facing    := to_player.normalized().dot(-transform.basis.z)

	if dist < attack_range and facing > attack_dot:
		_state = State.ATTACK
	else:
		_state = State.PURSUE


func _try_fire() -> void:
	if not _can_fire or not bullet_scene or not is_instance_valid(_gun_marker):
		return

	var bullet := bullet_scene.instantiate() as Area3D
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = _gun_marker.global_transform
	bullet.collision_layer  = 64  # layer 7: enemy_bullet
	bullet.collision_mask   = 8   # layer 4: player_hitbox

	_can_fire = false
	get_tree().create_timer(fire_rate).timeout.connect(func() -> void: _can_fire = true)


# ---------------------------------------------------------------------------
# Barrel roll
# ---------------------------------------------------------------------------
func _schedule_next_roll() -> void:
	var wait := randf_range(roll_interval_min, roll_interval_max)
	get_tree().create_timer(wait).timeout.connect(_start_barrel_roll)


func _start_barrel_roll() -> void:
	_rolling = true
	_roll_direction = 1.0 if randf() > 0.5 else -1.0
	get_tree().create_timer(roll_duration).timeout.connect(func() -> void:
		_rolling = false
		_schedule_next_roll()
	)


# ---------------------------------------------------------------------------
# Called by bullet.gd on hit
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if _health:
		_health.take_damage(amount)


# ---------------------------------------------------------------------------
# Detection zone
# ---------------------------------------------------------------------------
func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage") and body != self:
		_player = body
		_state  = State.PURSUE


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
		_state  = State.PATROL


# ---------------------------------------------------------------------------
# Death
# ---------------------------------------------------------------------------
func _on_died() -> void:
	_spawn_explosion()
	queue_free()


func _spawn_explosion() -> void:
	var pos := global_position   # capture before queue_free invalidates it

	# -----------------------------------------------------------------------
	# System 1 — Emissive core flash (bright, short-lived, hot centre)
	# -----------------------------------------------------------------------
	var core := GPUParticles3D.new()

	var core_mat := ParticleProcessMaterial.new()
	core_mat.direction            = Vector3(0.0, 1.0, 0.0)
	core_mat.spread               = 180.0
	core_mat.initial_velocity_min = 6.0
	core_mat.initial_velocity_max = 20.0
	core_mat.gravity              = Vector3(0.0, -2.0, 0.0)
	core_mat.scale_min            = 0.5
	core_mat.scale_max            = 1.4
	core_mat.damping_min          = 18.0
	core_mat.damping_max          = 32.0

	# White-hot → orange fade
	var core_grad := Gradient.new()
	core_grad.set_color(0,   Color(1.0, 1.0,  0.9, 1.0))  # white-hot
	core_grad.add_point(0.4, Color(1.0, 0.75, 0.0, 1.0))  # orange
	core_grad.add_point(1.0, Color(1.0, 0.2,  0.0, 0.0))  # deep red → transparent
	var core_grad_tex := GradientTexture1D.new()
	core_grad_tex.gradient = core_grad
	core_mat.color_ramp = core_grad_tex

	core.process_material = core_mat
	core.draw_pass_1      = _make_emissive_mesh()
	core.amount           = 20
	core.lifetime         = 0.35
	core.one_shot         = true
	core.explosiveness    = 1.0

	get_tree().current_scene.add_child(core)
	core.global_position = pos
	core.finished.connect(core.queue_free)

	# -----------------------------------------------------------------------
	# System 2 — Debris cloud (chunky low-poly pieces with emissive glow)
	# -----------------------------------------------------------------------
	var debris := GPUParticles3D.new()

	var deb_mat := ParticleProcessMaterial.new()
	deb_mat.direction            = Vector3(0.0, 1.0, 0.0)
	deb_mat.spread               = 180.0
	deb_mat.initial_velocity_min = 12.0
	deb_mat.initial_velocity_max = 35.0
	deb_mat.gravity              = Vector3(0.0, -6.0, 0.0)
	deb_mat.scale_min            = 0.4
	deb_mat.scale_max            = 1.2
	deb_mat.damping_min          = 8.0
	deb_mat.damping_max          = 18.0

	# Orange → yellow → hot white → grey smoke
	var deb_grad := Gradient.new()
	deb_grad.set_color(0,   Color(1.0, 0.35, 0.0, 1.0))
	deb_grad.add_point(0.3, Color(1.0, 0.80, 0.0, 1.0))
	deb_grad.add_point(0.6, Color(1.0, 1.00, 0.8, 0.8))
	deb_grad.add_point(1.0, Color(0.4, 0.40, 0.4, 0.0))
	var deb_grad_tex := GradientTexture1D.new()
	deb_grad_tex.gradient = deb_grad
	deb_mat.color_ramp = deb_grad_tex

	debris.process_material = deb_mat
	debris.draw_pass_1      = _make_debris_mesh()
	debris.amount           = 48
	debris.lifetime         = 0.9
	debris.one_shot         = true
	debris.explosiveness    = 1.0

	get_tree().current_scene.add_child(debris)
	debris.global_position = pos
	debris.finished.connect(debris.queue_free)


# Bright emissive sphere used by the core flash system
func _make_emissive_mesh() -> SphereMesh:
	var sphere           := SphereMesh.new()
	sphere.radius        = 0.55
	sphere.height        = 1.1
	sphere.radial_segments = 4
	sphere.rings         = 2

	var emissive_mat                        := StandardMaterial3D.new()
	emissive_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	emissive_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	emissive_mat.vertex_color_use_as_albedo = true
	emissive_mat.emission_enabled           = true
	emissive_mat.emission                   = Color(1.0, 0.6, 0.05)
	emissive_mat.emission_energy_multiplier = 5.0
	sphere.material = emissive_mat

	return sphere


# Low-poly chunk used by the debris cloud system
func _make_debris_mesh() -> SphereMesh:
	var sphere           := SphereMesh.new()
	sphere.radius        = 0.5
	sphere.height        = 1.0
	sphere.radial_segments = 4
	sphere.rings         = 2

	var deb_mat                        := StandardMaterial3D.new()
	deb_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	deb_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	deb_mat.vertex_color_use_as_albedo = true
	deb_mat.emission_enabled           = true
	deb_mat.emission                   = Color(1.0, 0.4, 0.0)
	deb_mat.emission_energy_multiplier = 2.5
	sphere.material = deb_mat

	return sphere


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _rotate_toward(target_pos: Vector3, speed: float, delta: float) -> void:
	var dir := (target_pos - global_position).normalized()
	var up  := Vector3.UP
	if abs(dir.dot(Vector3.UP)) > 0.99:
		up = Vector3.FORWARD
	var target_basis := Basis.looking_at(dir, up)
	transform.basis = transform.basis.slerp(target_basis, speed * delta).orthonormalized()


func _random_patrol_point() -> Vector3:
	var dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.4, 0.4),
		randf_range(-1.0, 1.0)
	).normalized()
	return dir * randf_range(80.0, 300.0)


func _get_boundary_force(pos: Vector3) -> Vector3:
	var dist := pos.length()
	if dist > arena_push_start:
		var t: float = clamp(
			(dist - arena_push_start) / (arena_radius - arena_push_start),
			0.0, 1.0
		)
		return -pos.normalized() * arena_push_strength * t * t
	return Vector3.ZERO
