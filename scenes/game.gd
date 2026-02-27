extends Node3D

enum CameraState {AIMING, FOLLOWING_BALL, RETURNING}

## Offset da câmera em relação ao alvo
@export var camera_offset: Vector3 = Vector3(-5, 2.5, 0)
## Velocidade de interpolação da câmera
@export var camera_smooth_speed: float = 5.0

const HUD_SCRIPT = preload("res://scenes/hud.gd")

var TREE_SCENES: Array[PackedScene] = [
	load("res://scenes/trees/normal_tree_1.tscn"),
	load("res://scenes/trees/normal_tree_2.tscn"),
	load("res://scenes/trees/normal_tree_3.tscn"),
	load("res://scenes/trees/normal_tree_4.tscn"),
	load("res://scenes/trees/normal_tree_5.tscn"),
]

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

	_spawn_trees()


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
			hud.update_state(tr("HUD_STATE_AIMING"))
		CameraState.FOLLOWING_BALL:
			hud.update_state(tr("HUD_STATE_TRACKING"))
		CameraState.RETURNING:
			hud.update_state(tr("HUD_STATE_RETURNING"))


# ── Árvores ──

func _spawn_trees() -> void:
	var tree_count := 60
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var tree_container := Node3D.new()
	tree_container.name = "Trees"
	add_child(tree_container)

	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < 500:
		attempts += 1
		var _maxDist = 20
		var x: float = rng.randf_range(-_maxDist, _maxDist)
		var z: float = rng.randf_range(-_maxDist, _maxDist)

		if _is_clear_zone(x, z):
			continue

		var tree_scene: PackedScene = TREE_SCENES[rng.randi_range(0, TREE_SCENES.size() - 1)]
		var tree: Node3D = tree_scene.instantiate()
		tree.position = Vector3(x, 0, z)
		#tree.rotation.y = rng.randf_range(0, TAU)
		var s: float = rng.randf_range(100.0, 180.0)
		tree.scale = Vector3(s, s, s)
		tree_container.add_child(tree)
		placed += 1


func _is_clear_zone(x: float, z: float) -> bool:
	# Zona do canhão e câmera
	if Vector2(x, z).length() < 5.0:
		return true
	# Corredor de tiro (+Z, faixa estreita em X)
	if z > 0 and abs(x) < 4.0:
		return true
	# Zona da câmera (atrás, -X perto do centro)
	if x < -3.0 and abs(z) < 3.0:
		return true
	return false
