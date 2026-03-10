extends Node3D

signal ball_fired(ball: RigidBody3D)

## Velocidade de rotação do ângulo (graus/segundo)
@export var angle_speed: float = 45.0
## Velocidade de ajuste da altura (unidades/segundo)
@export var height_speed: float = 2.0
## Força do disparo
@export var fire_power: float = 20.0

## Limites do ângulo em graus (elevação)
@export var min_angle: float = 5.0
@export var max_angle: float = 80.0

## Limites da altura
@export var min_height: float = 0.0
@export var max_height: float = 5.0

@onready var height_pivot: Node3D = $HeightPivot
@onready var angle_pivot: Node3D = $HeightPivot/AnglePivot
@onready var muzzle: Marker3D = $HeightPivot/AnglePivot/Muzzle

var current_angle: float = 45.0
var current_height: float = 0.0
var last_joy_axis: float = 0.0
var can_fire: bool = true
var _pedestal: CSGBox3D

var PROJECTILE_SCENE: PackedScene = load("res://scenes/projectile.tscn")


func _ready() -> void:
	current_angle = 45.0
	current_height = 0.0
	_create_pedestal()
	_apply_transforms()


func _process(delta: float) -> void:
	_handle_analog_input()
	_handle_angle_input(delta)
	_handle_height_input(delta)
	_handle_fire_input()


func _handle_analog_input() -> void:
	if not Input.get_connected_joypads().is_empty():
		var axis_val := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		
		# Ignoramos pequenos jitters do conversor ADC e só atualizamos se mecher o eixo
		if abs(axis_val - last_joy_axis) > 0.02:
			last_joy_axis = axis_val
			
			# O joystick vai de -1 a 1, normalizamos para 0.0 a 1.0 (onde -1.0 empurrado=100%, 1.0 puxado=0%)
			var normalized_val := (-axis_val + 1.0) / 2.0
			
			current_angle = min_angle + normalized_val * (max_angle - min_angle)
			current_angle = clamp(current_angle, min_angle, max_angle)
			_apply_transforms()


func _handle_angle_input(delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		current_angle += angle_speed * delta
	if Input.is_action_pressed("ui_down"):
		current_angle -= angle_speed * delta

	current_angle = clamp(current_angle, min_angle, max_angle)
	_apply_transforms()


func _handle_height_input(delta: float) -> void:
	if Input.is_action_pressed("cannon_height_up") or Input.is_action_pressed("cannon_shift"):
		current_height += height_speed * delta
	if Input.is_action_pressed("cannon_height_down"):
		current_height -= height_speed * delta

	# Se estourar a altura máxima, volta para zero (looping)
	if current_height >= max_height:
		current_height = min_height
	else:
		current_height = max(current_height, min_height)
		
	_apply_transforms()


func _handle_fire_input() -> void:
	if Input.is_action_just_pressed("cannon_fire") and can_fire:
		_fire()


func _apply_transforms() -> void:
	if height_pivot:
		height_pivot.position.y = current_height
	if angle_pivot:
		angle_pivot.rotation_degrees.x = current_angle - 80
	# Pedestal acompanha altura
	if _pedestal:
		var pedestal_h: float = current_height + 0.5 # mínimo visível
		_pedestal.size = Vector3(0.8, pedestal_h, 0.8)
		_pedestal.position.y = current_height / 2.0


func _create_pedestal() -> void:
	_pedestal = CSGBox3D.new()
	_pedestal.size = Vector3(0.8, 0.5, 0.8)
	_pedestal.position.y = 0.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.28, 0.32)
	mat.metallic = 0.6
	mat.roughness = 0.4
	_pedestal.material = mat
	add_child(_pedestal)


func _fire() -> void:
	can_fire = false

	var ball: RigidBody3D = PROJECTILE_SCENE.instantiate()
	
	# Gera uma cor vermelha bem vibrante para a trajetória
	ball.set("trail_color", Color(1.0, 0.1, 0.1))
	
	get_tree().current_scene.add_child(ball)

	ball.global_position = muzzle.global_position

	# Direção do disparo: para frente do muzzle (eixo +Z — modelo FBX aponta nessa direção)
	var fire_direction: Vector3 = muzzle.global_transform.basis.z.normalized()
	ball.linear_velocity = fire_direction * fire_power

	ball_fired.emit(ball)

	# Reativar disparo quando a bola for destruída
	ball.tree_exiting.connect(func(): can_fire = true)


func get_angle() -> float:
	return current_angle


func get_height() -> float:
	return current_height
