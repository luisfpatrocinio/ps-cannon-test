extends Node3D

enum CameraState {AIMING, FOLLOWING_BALL, IMPACT, OVERVIEW, TRANSITIONING, RETURNING}

## Offset da câmera em relação ao alvo
@export var camera_offset: Vector3 = Vector3(-5, 2.5, 0)
## Velocidade de interpolação da câmera
@export var camera_smooth_speed: float = 5.0
## Tempo que a câmera fica fixa no ponto de impacto (segundos)
@export var impact_hold_time: float = 3.5
## Multiplicador de distância para o zoom da Visão Geral (menor = mais próximo)
@export var overview_zoom_multiplier: float = 0.6

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

# ── Impacto ──
var _launch_position: Vector3 = Vector3.ZERO
var _impact_timer: float = 0.0
var _impact_label: Label3D = null

# ── Visão Geral ──
var _overview_camera_pos: Vector3
var _overview_look_at: Vector3
var _overview_lines: Array[Node] = []
var _impact_pos_cache: Vector3
var _max_height_cache: Vector3
var _distance_cache: float = 0.0

var _overview_ui: Control = null
var _h_label_2d: Label = null
var _d_label_2d: Label = null
var _h_pos_3d: Vector3
var _d_pos_3d: Vector3


func _ready() -> void:
	# Instanciar HUD via código (sem .tscn)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)

	cannon.ball_fired.connect(_on_ball_fired)
	_update_camera_immediate()
	hud.update_power(cannon.fire_power)

	_spawn_trees()


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var window = get_window()
		
		# Evita erro "embedded window only supports windowed mode" (comum rodando no Editor)
		if window.has_method("is_embedded") and window.is_embedded():
			print("HUD: Fullscreen bloqueado pois a janela atual está embutida (ex: Godot Editor).")
			return
			
		if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_FULLSCREEN


func _physics_process(delta: float) -> void:
	match camera_state:
		CameraState.AIMING:
			_camera_follow_cannon(delta)
		CameraState.FOLLOWING_BALL:
			_camera_follow_ball(delta)
		CameraState.IMPACT:
			_camera_hold_impact(delta)
		CameraState.OVERVIEW:
			_camera_hold_overview(delta)
		CameraState.TRANSITIONING:
			pass
		CameraState.RETURNING:
			_camera_return_to_cannon(delta)


func _camera_follow_cannon(delta: float) -> void:
	var target_pos = cannon.global_position + Vector3(0, cannon.get_height(), 0)
	var desired = target_pos + camera_offset
	camera.global_position = camera.global_position.lerp(desired, camera_smooth_speed * delta)
	camera.look_at(target_pos, Vector3.UP)


func _camera_follow_ball(delta: float) -> void:
	if not is_instance_valid(follow_target):
		_begin_return()
		return

	var target_pos = follow_target.global_position
	var desired = target_pos + camera_offset
	camera.global_position = camera.global_position.lerp(desired, camera_smooth_speed * delta)
	camera.look_at(target_pos, Vector3.UP)


func _camera_hold_impact(_delta: float) -> void:
	_impact_timer += _delta

	if _impact_timer >= 1.5:
		_cleanup_impact_label()
		_begin_overview()


func _camera_return_to_cannon(delta: float) -> void:
	_return_timer += delta

	var target_pos = cannon.global_position + Vector3(0, cannon.get_height(), 0)
	var desired = target_pos + camera_offset
	# Aceleramos um pouco o retorno visual
	camera.global_position = camera.global_position.lerp(desired, camera_smooth_speed * 1.5 * delta)
	camera.look_at(target_pos, Vector3.UP)

	# Quando estiver perto o suficiente, volta ao estado AIMING
	if camera.global_position.distance_to(desired) < 0.1 or _return_timer > 3.0:
		camera_state = CameraState.AIMING


func _update_camera_immediate() -> void:
	var target_pos = cannon.global_position + Vector3(0, cannon.get_height(), 0)
	camera.global_position = target_pos + camera_offset
	camera.look_at(target_pos, Vector3.UP)


func _begin_return() -> void:
	if camera_state == CameraState.RETURNING or camera_state == CameraState.TRANSITIONING:
		return
	
	camera_state = CameraState.TRANSITIONING
	
	# Inicia o fade to black e espera a tela ficar preta
	await hud.play_transition(0.3, 0.1, 0.5)
	
	# Quando a tela está preta, começamos o retorno da câmera
	follow_target = null
	camera_state = CameraState.RETURNING
	_return_timer = 0.0
	hud.show_crosshair(true)
	cannon.set_process(true)


func _begin_overview() -> void:
	camera_state = CameraState.OVERVIEW
	cannon.set_process(false)
	
	var center = (_launch_position + _impact_pos_cache) / 2.0
	var req_width = _impact_pos_cache.z - _launch_position.z
	var req_height = _max_height_cache.y - _launch_position.y
	
	var base_dist_x = max(abs(req_width) * 0.8, abs(req_height) * 1.5)
	var dist_x = (base_dist_x + 10.0) * overview_zoom_multiplier
	var cam_height = max((req_height * 0.5 + 4.0) * overview_zoom_multiplier, 2.0)
	
	_overview_camera_pos = center + Vector3(-dist_x, cam_height, 0)
	_overview_look_at = center
	
	_draw_overview_lines(_max_height_cache, _impact_pos_cache, _distance_cache)

func _camera_hold_overview(delta: float) -> void:
	hud.hide()
	camera.global_position = camera.global_position.lerp(_overview_camera_pos, camera_smooth_speed * delta)
	
	var current_look = camera.global_transform.basis.z * -1
	var target_look = camera.global_position.direction_to(_overview_look_at)
	var new_look = current_look.lerp(target_look, camera_smooth_speed * delta).normalized()
	if new_look.length_squared() > 0:
		camera.look_at(camera.global_position + new_look, Vector3.UP)

	if _overview_ui and is_instance_valid(_overview_ui):
		var time_sec = float(Time.get_ticks_msec()) / 1000.0
		var float_offset_h = Vector2(0, sin(time_sec * 3.5) * 12.0)
		var float_offset_d = Vector2(0, sin(time_sec * 3.5 + 1.0) * 12.0)
		
		if not camera.is_position_behind(_h_pos_3d) and _h_label_2d:
			_h_label_2d.position = camera.unproject_position(_h_pos_3d) - _h_label_2d.size / 2.0 + float_offset_h
		if not camera.is_position_behind(_d_pos_3d) and _d_label_2d:
			_d_label_2d.position = camera.unproject_position(_d_pos_3d) - _d_label_2d.size / 2.0 + float_offset_d

	# Sai da visão geral e retorna caso o jogador aperte o botão de atirar
	if Input.is_action_just_pressed("cannon_fire"):
		_cleanup_overview_lines()
		_begin_return()
		hud.show()

func _draw_overview_lines(max_h_point: Vector3, impact_pos: Vector3, distance: float) -> void:
	_cleanup_overview_lines()
	
	var launch_floor = Vector3(_launch_position.x, 0.05, _launch_position.z)
	var impact_floor = Vector3(impact_pos.x, 0.05, impact_pos.z)
	
	# Height line
	var max_h_floor = Vector3(max_h_point.x, 0.05, max_h_point.z)
	var h_line = _create_cylinder_line(max_h_floor, max_h_point, Color.RED)
	_overview_lines.append(h_line)
	
	# Distance line
	var d_line = _create_cylinder_line(launch_floor, impact_floor, Color.AQUA)
	_overview_lines.append(d_line)
	
	# Create 2D Canvas for Labels
	_overview_ui = Control.new()
	add_child(_overview_ui)
	
	var font_settings = LabelSettings.new()
	font_settings.font_size = 28
	font_settings.font_color = Color.WHITE
	font_settings.outline_color = Color(0.1, 0.1, 0.1, 0.9)
	font_settings.outline_size = 10
	
	_h_pos_3d = max_h_point + Vector3(0, 1.5, 0)
	_h_label_2d = Label.new()
	_h_label_2d.text = tr("LBL_MAX_HEIGHT") % max_h_point.y
	_h_label_2d.label_settings = font_settings
	_overview_ui.add_child(_h_label_2d)
	
	_d_pos_3d = (launch_floor + impact_floor) / 2.0 + Vector3(0, 1.5, 0)
	_d_label_2d = Label.new()
	_d_label_2d.text = tr("LBL_TOTAL_DISTANCE") % distance
	_d_label_2d.label_settings = font_settings
	_overview_ui.add_child(_d_label_2d)

func _create_cylinder_line(start: Vector3, end: Vector3, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.15
	mesh.height = start.distance_to(end)
	mi.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	
	mi.position = (start + end) / 2.0
	
	var dir = start.direction_to(end)
	if dir.length_squared() > 0.001:
		if abs(dir.dot(Vector3.UP)) < 0.999:
			var axis = Vector3.UP.cross(dir).normalized()
			var angle = Vector3.UP.angle_to(dir)
			mi.quaternion = Quaternion(axis, angle)
		else:
			if dir.y < 0:
				mi.quaternion = Quaternion(Vector3.RIGHT, PI)
				
	add_child(mi)
	return mi

func _cleanup_overview_lines() -> void:
	for line in _overview_lines:
		if is_instance_valid(line):
			line.queue_free()
	_overview_lines.clear()
	
	if _overview_ui and is_instance_valid(_overview_ui):
		_overview_ui.queue_free()
		_overview_ui = null
		_h_label_2d = null
		_d_label_2d = null


func _on_ball_fired(ball: RigidBody3D) -> void:
	# Limpa qualquer rastro da bola anterior
	get_tree().call_group("trail_dots", "queue_free")

	# Limpar label de impacto anterior, se existir
	_cleanup_impact_label()

	_launch_position = ball.global_position
	follow_target = ball
	camera_state = CameraState.FOLLOWING_BALL
	hud.flash_fire()
	hud.show_crosshair(false)

	# Conectar sinal de pouso
	ball.landed.connect(_on_ball_landed.bind(ball))

	# Fallback: quando a bola sair da árvore, volta a câmera
	ball.tree_exiting.connect(func():
		if camera_state == CameraState.FOLLOWING_BALL:
			_begin_return()
	)


func _on_ball_landed(ball: RigidBody3D) -> void:
	if not is_instance_valid(ball):
		return

	var impact_pos: Vector3 = ball.global_position
	# Força a posição Y para ficar rente ao chão (0.0 ou quase)
	impact_pos.y = 0.05
	
	_impact_pos_cache = impact_pos
	
	var max_h_val = ball.get("max_height_point")
	if typeof(max_h_val) != TYPE_NIL and max_h_val != Vector3.ZERO:
		_max_height_cache = max_h_val
	else:
		_max_height_cache = _launch_position
		
	var distance: float = _launch_position.distance_to(impact_pos)
	_distance_cache = distance

	# Transição para estado de impacto
	camera_state = CameraState.IMPACT
	_impact_timer = 0.0

	_create_impact_marker(impact_pos)
	_create_impact_label(impact_pos, distance)


func _create_impact_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.6
	cylinder.height = 0.1
	marker.mesh = cylinder
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1, 0.8) # Cinza escuro, como uma cratera
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	marker.material_override = mat
	
	marker.position = pos
	add_child(marker)
	
	# Animação simulando impacto (expansão)
	marker.scale = Vector3.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(marker, "scale", Vector3.ONE, 0.3)


func _create_impact_label(impact_pos: Vector3, distance: float) -> void:
	_impact_label = Label3D.new()
	_impact_label.text = "%.1f m" % distance
	_impact_label.font_size = 72
	_impact_label.pixel_size = 0.01
	_impact_label.outline_size = 12
	_impact_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_impact_label.outline_modulate = Color(0.1, 0.1, 0.15, 0.9)
	_impact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_impact_label.no_depth_test = true
	_impact_label.position = impact_pos + Vector3(0, 1.5, 0)

	add_child(_impact_label)

	# Animação de entrada: escala de 0 → 1
	_impact_label.scale = Vector3.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_impact_label, "scale", Vector3.ONE, 0.4)


func _cleanup_impact_label() -> void:
	if _impact_label and is_instance_valid(_impact_label):
		_impact_label.queue_free()
		_impact_label = null


func _update_hud() -> void:
	hud.update_angle(cannon.get_angle(), cannon.min_angle, cannon.max_angle)
	hud.update_height(cannon.get_height(), cannon.min_height, cannon.max_height)

	match camera_state:
		CameraState.AIMING:
			hud.update_state(tr("HUD_STATE_AIMING"))
		CameraState.FOLLOWING_BALL:
			hud.update_state(tr("HUD_STATE_TRACKING"))
		CameraState.IMPACT, CameraState.TRANSITIONING:
			hud.update_state(tr("HUD_STATE_IMPACT"))
		CameraState.OVERVIEW:
			hud.update_state(tr("HUD_STATE_OVERVIEW"))
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
		var _maxDist = 100
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
