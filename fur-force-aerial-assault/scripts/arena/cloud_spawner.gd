extends Node3D

@export var cloud_count  : int   = 50
@export var spawn_radius : float = 460.0

# Three material variants for inner / mid / outer layers
var _mat_core:  StandardMaterial3D
var _mat_mid:   StandardMaterial3D
var _mat_outer: StandardMaterial3D

var _cloud_script = preload("res://scripts/environment/cloud.gd")


func _ready() -> void:
	_mat_core  = _make_material(Color(1.0, 1.0, 1.0, 0.72))
	_mat_mid   = _make_material(Color(1.0, 1.0, 1.0, 0.50))
	_mat_outer = _make_material(Color(1.0, 1.0, 1.0, 0.28))

	for i in cloud_count:
		_spawn_cloud()


# ---------------------------------------------------------------------------
# Build one cloud cluster
# ---------------------------------------------------------------------------
func _spawn_cloud() -> void:
	var cloud := Node3D.new()
	cloud.set_script(_cloud_script)

	# Random position spread through the arena
	var dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 0.5),
		randf_range(-1.0, 1.0)
	).normalized()
	cloud.position = dir * randf_range(30.0, spawn_radius)

	# Drift / wobble properties
	cloud.drift_direction  = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	cloud.drift_speed      = randf_range(1.0, 3.5)
	cloud.wobble_amplitude = randf_range(0.15, 0.5)
	cloud.wobble_speed     = randf_range(0.1,  0.35)
	cloud.arena_radius     = spawn_radius + 80.0
	cloud.steer_radius     = spawn_radius
	cloud._time_offset     = randf_range(0.0, TAU)

	# Overall size variation per cloud
	var scale_factor := randf_range(0.8, 2.2)

	# --- Dense core (1–2 large spheres) ---
	for _j in randi_range(1, 2):
		_add_sphere(cloud, _mat_core,
			randf_range(14.0, 22.0) * scale_factor,
			Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-6.0, 6.0))
		)

	# --- Mid layer (3–5 medium spheres) ---
	for _j in randi_range(3, 5):
		_add_sphere(cloud, _mat_mid,
			randf_range(9.0, 16.0) * scale_factor,
			Vector3(randf_range(-22.0, 22.0), randf_range(-7.0, 7.0), randf_range(-18.0, 18.0))
		)

	# --- Outer fluffy layer (4–6 smaller transparent spheres) ---
	for _j in randi_range(4, 6):
		_add_sphere(cloud, _mat_outer,
			randf_range(5.0, 13.0) * scale_factor,
			Vector3(randf_range(-35.0, 35.0), randf_range(-12.0, 12.0), randf_range(-28.0, 28.0))
		)

	add_child(cloud)


func _add_sphere(
	parent: Node3D,
	mat:    StandardMaterial3D,
	radius: float,
	offset: Vector3
) -> void:
	var mesh_inst := MeshInstance3D.new()
	var sphere    := SphereMesh.new()
	sphere.radius          = radius
	sphere.height          = radius * 2.0
	sphere.radial_segments = 12   # rounder than default
	sphere.rings           = 6
	mesh_inst.mesh              = sphere
	mesh_inst.material_override = mat
	mesh_inst.position          = offset
	parent.add_child(mesh_inst)


# ---------------------------------------------------------------------------
# Material factory — one call per opacity level, shared across all clouds
# ---------------------------------------------------------------------------
func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color    = color
	mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode       = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -1
	return mat
