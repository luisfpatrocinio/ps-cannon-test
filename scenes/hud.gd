extends CanvasLayer
## HUD do canhão - construída inteiramente via código para evitar problemas de parse do .tscn

# Referências dos nós (criados em _ready)
var angle_bar: ProgressBar
var angle_label: Label
var height_bar: ProgressBar
var height_label: Label
var power_label: Label
var state_label: Label
var crosshair: Control

var _flash_timer: float = 0.0
var _show_fire_flash: bool = false

var _transition_rect: ColorRect

func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	if _show_fire_flash:
		_flash_timer -= delta
		if _flash_timer <= 0:
			_show_fire_flash = false
			state_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))


func update_angle(val: float, min_val: float, max_val: float) -> void:
	angle_bar.min_value = min_val
	angle_bar.max_value = max_val
	angle_bar.value = val
	angle_label.text = "%.1f°" % val


func update_height(val: float, min_val: float, max_val: float) -> void:
	height_bar.min_value = min_val
	height_bar.max_value = max_val
	height_bar.value = val
	height_label.text = "%.1f m" % val


func update_power(val: float) -> void:
	power_label.text = "%.0f" % val


func update_state(state_name: String) -> void:
	state_label.text = state_name


func flash_fire() -> void:
	_show_fire_flash = true
	_flash_timer = 0.4
	state_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))


func show_crosshair(val: bool) -> void:
	crosshair.visible = val


func play_transition(fade_in_time: float = 0.3, hold_time: float = 0.1, fade_out_time: float = 0.3) -> Signal:
	_transition_rect.visible = true
	_transition_rect.modulate.a = 0.0
	
	var tween := create_tween()
	# Fade out da visão (tela fica preta)
	tween.tween_property(_transition_rect, "modulate:a", 1.0, fade_in_time)
	# Fica preta um momentinho
	tween.tween_interval(hold_time)
	# Fade in da visão (tela volta a ficar transparente)
	tween.tween_property(_transition_rect, "modulate:a", 0.0, fade_out_time)
	
	tween.finished.connect(func(): _transition_rect.visible = false)
	
	# Retorna um signal que pode ser esperado quando o fade-in estiver completo (tela totalmente preta/momento ideal pra corte)
	return get_tree().create_timer(fade_in_time).timeout


# ============================================================
# Construção da UI
# ============================================================

func _build_ui() -> void:
	_build_top_bar()
	_build_left_panel()
	_build_bottom_controls()
	_build_crosshair()
	_build_transition_rect()


func _build_transition_rect() -> void:
	_transition_rect = ColorRect.new()
	_transition_rect.color = Color.BLACK
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.visible = false
	add_child(_transition_rect)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 250.0
	bar.offset_right = -250.0
	bar.offset_bottom = 48.0

	var style := _make_style(Color(0.03, 0.06, 0.12, 0.9))
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.5, 0.9, 0.4)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	bar.add_child(hbox)

	var title := Label.new()
	title.text = tr("HUD_TITLE")
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.8))
	title.add_theme_font_size_override("font_size", 14)
	hbox.add_child(title)

	var sep := VSeparator.new()
	hbox.add_child(sep)

	state_label = Label.new()
	state_label.text = tr("HUD_STATE_AIMING")
	state_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	state_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(state_label)

	add_child(bar)


func _build_left_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 65)
	panel.size = Vector2(240, 270)

	var style := _make_style(Color(0.05, 0.08, 0.15, 0.85))
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.5, 0.9, 0.6)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.0, 0.3, 0.8, 0.15)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Título do painel
	var panel_title := Label.new()
	panel_title.text = tr("HUD_PARAMETERS")
	panel_title.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0, 0.9))
	panel_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(panel_title)

	# Separador
	vbox.add_child(HSeparator.new())

	# --- ANGLE ---
	var angle_header := _make_param_header(tr("HUD_ANGLE"), Color(0.3, 0.6, 1.0))
	angle_label = angle_header.get_child(1)
	angle_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(angle_header)

	angle_bar = _make_progress_bar(
		Color(0.08, 0.12, 0.22), Color(0.2, 0.6, 1.0),
		5.0, 80.0, 45.0
	)
	vbox.add_child(angle_bar)

	# --- HEIGHT ---
	var height_header := _make_param_header(tr("HUD_HEIGHT"), Color(0.2, 0.9, 0.4))
	height_label = height_header.get_child(1)
	height_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vbox.add_child(height_header)

	height_bar = _make_progress_bar(
		Color(0.08, 0.12, 0.22), Color(0.2, 0.9, 0.4),
		0.0, 5.0, 0.0
	)
	vbox.add_child(height_bar)

	# --- Separador ---
	vbox.add_child(HSeparator.new())

	# --- POWER ---
	var power_header := _make_param_header(tr("HUD_POWER"), Color(1.0, 0.6, 0.2))
	power_label = power_header.get_child(1)
	power_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	power_label.text = "20"
	vbox.add_child(power_header)

	add_child(panel)


func _build_bottom_controls() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -55.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := _make_style(Color(0.05, 0.08, 0.15, 0.75))
	style.border_width_top = 1
	style.border_color = Color(0.2, 0.5, 0.9, 0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	margin.add_child(hbox)

	_add_control_hint(hbox, tr("HUD_CTRL_ANGLE"), Color(0.6, 0.75, 0.95, 0.9))
	_add_control_hint(hbox, tr("HUD_CTRL_HEIGHT"), Color(0.6, 0.95, 0.7, 0.9))
	_add_control_hint(hbox, tr("HUD_CTRL_FIRE"), Color(1.0, 0.75, 0.4, 0.9))

	add_child(panel)


func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var h_line := ColorRect.new()
	h_line.color = Color(1, 1, 1, 0.45)
	h_line.set_anchors_preset(Control.PRESET_CENTER)
	h_line.offset_left = -16; h_line.offset_right = 16
	h_line.offset_top = -1; h_line.offset_bottom = 1
	crosshair.add_child(h_line)

	var v_line := ColorRect.new()
	v_line.color = Color(1, 1, 1, 0.45)
	v_line.set_anchors_preset(Control.PRESET_CENTER)
	v_line.offset_left = -1; v_line.offset_right = 1
	v_line.offset_top = -16; v_line.offset_bottom = 16
	crosshair.add_child(v_line)

	var dot := ColorRect.new()
	dot.color = Color(0.3, 0.7, 1.0, 0.8)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -3; dot.offset_right = 3
	dot.offset_top = -3; dot.offset_bottom = 3
	crosshair.add_child(dot)

	add_child(crosshair)


# ============================================================
# Helpers
# ============================================================

func _make_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	return s


func _make_param_header(title: String, color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()

	var icon_label := Label.new()
	icon_label.text = title
	icon_label.add_theme_color_override("font_color", color)
	icon_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(icon_label)

	var value_label := Label.new()
	value_label.text = "---"
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(value_label)

	return hbox


func _make_progress_bar(bg_color: Color, fill_color: Color, min_val: float, max_val: float, val: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 12
	bar.min_value = min_val
	bar.max_value = max_val
	bar.value = val
	bar.show_percentage = false

	var bg_style := _make_style(bg_color)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_right = 6
	bg_style.corner_radius_bottom_left = 6

	var fill_style := _make_style(fill_color)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar


func _add_control_hint(parent: HBoxContainer, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
