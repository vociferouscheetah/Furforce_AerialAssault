extends Camera3D

# --- Follow distances ---
@export var follow_distance    :=  5.0   # units behind the player
@export var follow_height      :=  2.0   # units above the player
@export var look_ahead         :=  5.0   # look slightly in front of player

# --- FOV ---
@export var fov_normal         := 70.0
@export var fov_boost          := 85.0

# --- Smoothing ---
@export var camera_lerp_speed         :=  5.0
@export var camera_lerp_speed_boost   := 12.0

var _player: Node3D


func _ready() -> void:
	# Detach from parent's transform so we can manage position ourselves
	set_as_top_level(true)
	_player = get_parent() as Node3D

	# Snap to the correct position on the first frame instead of lerping from origin
	if _player:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if not _player:
		return

	# Smoothly follow the desired position — tighten up when boosting to avoid lag
	var lerp_speed := camera_lerp_speed_boost if _player.get("is_boosting") else camera_lerp_speed
	global_position = global_position.lerp(_desired_position(), lerp_speed * delta)

	# Look slightly ahead of the player's nose
	var look_target := _player.global_position + (-_player.global_transform.basis.z * look_ahead)
	var look_dir    := look_target - global_position
	if look_dir.length_squared() > 0.001:
		look_at(look_target, Vector3.UP)

	# FOV punch when boosting
	var target_fov: float = fov_boost if _player.get("is_boosting") else fov_normal
	fov = lerpf(fov, target_fov, 3.0 * delta)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _desired_position() -> Vector3:
	# Behind (+Z in local space) and above the player
	return _player.global_position \
		+ _player.global_transform.basis.z * follow_distance \
		+ Vector3.UP * follow_height
