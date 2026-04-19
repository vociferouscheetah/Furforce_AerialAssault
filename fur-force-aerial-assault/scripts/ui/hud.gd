extends CanvasLayer

# Drag the Player and EnemySpawner nodes into these fields in the Inspector
@export var player_node:  NodePath
@export var spawner_node: NodePath

@onready var health_bar:   ProgressBar = $HealthBar
@onready var speed_label:  Label       = $SpeedLabel
@onready var score_label:  Label       = $ScoreLabel

var _player:  Node   = null
var _spawner: Node   = null
var _score:   int    = 0


func _ready() -> void:
	# Resolve node references from exported paths
	if not player_node.is_empty():
		_player = get_node(player_node)
	if not spawner_node.is_empty():
		_spawner = get_node(spawner_node)

	# Connect player health bar
	if _player:
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health_bar.max_value = health.max_health
			health_bar.value     = health.current_health
			health.health_changed.connect(_on_health_changed)

	# Connect kill score
	if _spawner and _spawner.has_signal("enemy_killed"):
		_spawner.enemy_killed.connect(_on_enemy_killed)

	_update_score_label()


func _process(_delta: float) -> void:
	# Update speed every frame — read directly from player_controller
	if _player:
		var spd: float = _player.get("current_speed")
		if spd != null:
			speed_label.text = "SPD  %d" % int(spd)


# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------
func _on_health_changed(new_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value     = new_health


func _on_enemy_killed() -> void:
	_score += 1
	_update_score_label()


func _update_score_label() -> void:
	score_label.text = "KILLS  %d" % _score
