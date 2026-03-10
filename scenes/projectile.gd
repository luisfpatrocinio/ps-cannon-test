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

var trail_color: Color = Color.WHITE
var _trail_timer: float = 0.0
var trail_interval: float = 0.05

var max_height_point: Vector3 = Vector3.ZERO

signal landed


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta

	if not has_landed:
		if global_position.y > max_height_point.y or max_height_point == Vector3.ZERO:
			max_height_point = global_position
			
		_trail_timer += delta
		if _trail_timer >= trail_interval:
			_trail_timer = 0.0
			_spawn_trail_dot()

	# Auto-destruição por tempo
	if _age >= lifetime:
		queue_free()
		return
		
	# Destrói depois de ficar parada se já pousou
	if has_landed and linear_velocity.length() < rest_speed:
		_rest_timer += delta
		if _rest_timer >= rest_time:
			queue_free()
	else:
		_rest_timer = 0.0


func _on_body_entered(_body: Node) -> void:
	if not has_landed:
		has_landed = true
		landed.emit()


func _spawn_trail_dot() -> void:
	var dot = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	dot.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = trail_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material_override = mat
	
	# Adicionamos a bolinha na árvore raiz do jogo para ela não sumir com o projétil
	get_tree().current_scene.add_child(dot)
	dot.global_position = global_position
	
	# Adiciona a bolinha a um grupo específico para ser limpa na próxima vez
	dot.add_to_group("trail_dots")
