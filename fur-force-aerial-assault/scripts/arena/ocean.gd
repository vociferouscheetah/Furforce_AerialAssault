extends Node3D

# Size of the ocean plane in world units — must reach the fog boundary
@export var ocean_size    : float = 12000.0
# More subdivisions = smoother waves but heavier GPU cost
@export var subdivisions  : int   = 200
# Height below world origin — set low enough to sit under the action
@export var ocean_y       : float = -180.0


func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()

	# Large subdivided plane
	var plane              := PlaneMesh.new()
	plane.size              = Vector2(ocean_size, ocean_size)
	plane.subdivide_width   = subdivisions
	plane.subdivide_depth   = subdivisions

	# Load the shader and assign it
	var shader_mat         := ShaderMaterial.new()
	shader_mat.shader       = load("res://assets/materials/ocean.gdshader")

	mesh_instance.mesh              = plane
	mesh_instance.material_override = shader_mat
	mesh_instance.position.y        = ocean_y

	add_child(mesh_instance)
