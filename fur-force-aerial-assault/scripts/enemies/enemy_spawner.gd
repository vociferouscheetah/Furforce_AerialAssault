extends Node3D

## Emitted every time a player kill removes an enemy from the scene
signal enemy_killed

@export var enemy_scene:     PackedScene
@export var enemy_count:     int   = 50
@export var spawn_radius:    float = 150.0
@export var min_spawn_radius: float =  40.0
@export var spawn_delay:     float =  3.0   # seconds before respawning a dead enemy

var _active_count := 0


func _ready() -> void:
	if not enemy_scene:
		push_warning("EnemySpawner: enemy_scene is not set in the Inspector.")
		return

	for i in enemy_count:
		_spawn_enemy()


# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------
func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate()
	enemy.global_position = _random_spawn_point()
	enemy.look_at(Vector3.ZERO, Vector3.UP)
	add_child(enemy)

	_active_count += 1
	# When this enemy leaves the scene tree (dies), schedule a replacement
	enemy.tree_exiting.connect(_on_enemy_removed)


func _on_enemy_removed() -> void:
	_active_count -= 1
	enemy_killed.emit()
	get_tree().create_timer(spawn_delay).timeout.connect(func() -> void:
		if _active_count < enemy_count:
			_spawn_enemy()
	)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _random_spawn_point() -> Vector3:
	var dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.3, 0.3),
		randf_range(-1.0, 1.0)
	).normalized()
	return dir * randf_range(min_spawn_radius, spawn_radius)
