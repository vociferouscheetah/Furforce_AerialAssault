extends Area3D

@export var speed    := 150.0
@export var lifetime :=   2.0
@export var damage   :=  25.0


func _ready() -> void:
	# Auto-destroy after lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	# Connect hit detection
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# Always travel forward along local -Z
	position += -transform.basis.z * speed * delta


func _on_area_entered(area: Area3D) -> void:
	# The collision mask ensures only enemy hitboxes trigger this,
	# but we double-check with has_method for safety
	var enemy := area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	queue_free()
