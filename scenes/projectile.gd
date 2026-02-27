extends RigidBody3D

## Tempo em segundos antes de auto-destruição
@export var lifetime: float = 8.0

## Velocidade mínima para considerar a bola "parada"
@export var rest_speed: float = 0.3

## Tempo parada antes de destruir (segundos)
@export var rest_time: float = 2.0

var _rest_timer: float = 0.0
var _age: float = 0.0
var has_landed: bool = false

signal landed


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4


func _physics_process(delta: float) -> void:
	_age += delta

	# Auto-destruição por tempo
	if _age >= lifetime:
		queue_free()
		return

	# Detectar quando a bola está quase parada
	if _age > 0.5 and linear_velocity.length() < rest_speed:
		_rest_timer += delta
		if _rest_timer >= rest_time and not has_landed:
			has_landed = true
			landed.emit()
			# Espera um pouco e remove
			await get_tree().create_timer(1.0).timeout
			queue_free()
	else:
		_rest_timer = 0.0
