extends Node

# Set this to bullet.tscn in the Inspector
@export var bullet_scene: PackedScene
@export var fire_rate := 0.1   # seconds between shots

var _can_fire    := true
var _muzzle_index := 0

@onready var _muzzle_left:  Marker3D = $"../PlayerModel/GunLeft"
@onready var _muzzle_right: Marker3D = $"../PlayerModel/GunRight"


func _process(_delta: float) -> void:
	if Input.is_action_pressed("fire") and _can_fire:
		_fire()


func _fire() -> void:
	if not bullet_scene:
		push_warning("player_weapons: bullet_scene is not set in the Inspector.")
		return

	# Alternate between left and right gun
	var muzzle: Marker3D = _muzzle_left if _muzzle_index == 0 else _muzzle_right
	_muzzle_index = (_muzzle_index + 1) % 2

	# Spawn bullet at muzzle position/rotation in world space
	var bullet := bullet_scene.instantiate()
	bullet.global_transform = muzzle.global_transform
	get_tree().current_scene.add_child(bullet)

	# Start cooldown
	_can_fire = false
	get_tree().create_timer(fire_rate).timeout.connect(func() -> void: _can_fire = true)
