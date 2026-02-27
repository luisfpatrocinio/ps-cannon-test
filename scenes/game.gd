extends Node3D

enum CameraState {AIMING, FOLLOWING_BALL, RETURNING}

## Offset da câmera em relação ao alvo
@export var camera_offset: Vector3 = Vector3(-5, 2.5, 0)
## Velocidade de interpolação da câmera
@export var camera_smooth_speed: float = 5.0

const HUD_SCRIPT = preload("res://scenes/hud.gd")

@onready var cannon: Node3D = $Cannon
@onready var camera: Camera3D = $Camera3D

var hud: CanvasLayer
var camera_state: CameraState = CameraState.AIMING
var follow_target: Node3D = null
var _return_timer: float = 0.0


func _ready() -> void:
	# Instanciar HUD via código (sem .tscn)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)

	cannon.ball_fired.connect(_on_ball_fired)
	_update_camera_immediate()
	hud.update_power(cannon.fire_power)


func _process(delta: float) -> void:
	_update_hud()

	match camera_state:
		CameraState.AIMING:
			_camera_follow_cannon(delta)
		CameraState.FOLLOWING_BALL:
			_camera_follow_ball(delta)
		CameraState.RETURNING:
			_camera_return_to_cannon(delta)


func _camera_follow_cannon(delta: float) -> void:
	var target_pos = cannon.global_position + Vector3(0, cannon.get_height(), 0)
	var desired = target_pos + camera_offset
	camera.global_position = camera.global_position.lerp(desired, camera_smooth_speed * delta)
	camera.look_at(target_pos, Vector3.UP)


func _camera_follow_ball(delta: float) -> void:
	if not is_instance_valid(follow_target):
		camera_state = CameraState.RETURNING
		_return_timer = 0.0
		return

	var target_pos = follow_target.global_position
	var desired = target_pos + camera_offset
	camera.global_position = camera.global_position.lerp(desired, camera_smooth_speed * delta)
	camera.look_at(target_pos, Vector3.UP)


func _camera_return_to_cannon(delta: float) -> void:
	_return_timer += delta

	var target_pos = cannon.global_position + Vector3(0, cannon.get_height(), 0)
	var desired = target_pos + camera_offset
	camera.global_position = camera.global_position.lerp(desired, camera_smooth_speed * 0.5 * delta)
	camera.look_at(target_pos, Vector3.UP)

	# Quando estiver perto o suficiente, volta ao estado AIMING
	if camera.global_position.distance_to(desired) < 0.1 or _return_timer > 3.0:
		camera_state = CameraState.AIMING


func _update_camera_immediate() -> void:
	var target_pos = cannon.global_position + Vector3(0, cannon.get_height(), 0)
	camera.global_position = target_pos + camera_offset
	camera.look_at(target_pos, Vector3.UP)


func _on_ball_fired(ball: RigidBody3D) -> void:
	follow_target = ball
	camera_state = CameraState.FOLLOWING_BALL
	hud.flash_fire()
	hud.show_crosshair(false)

	# Quando a bola sair da árvore, volta a câmera
	ball.tree_exiting.connect(func():
		follow_target = null
		camera_state = CameraState.RETURNING
		_return_timer = 0.0
		hud.show_crosshair(true)
	)


func _update_hud() -> void:
	hud.update_angle(cannon.get_angle(), cannon.min_angle, cannon.max_angle)
	hud.update_height(cannon.get_height(), cannon.min_height, cannon.max_height)

	match camera_state:
		CameraState.AIMING:
			hud.update_state("◎ AIMING")
		CameraState.FOLLOWING_BALL:
			hud.update_state("● TRACKING")
		CameraState.RETURNING:
			hud.update_state("◌ RETURNING")
