extends Control
## Menu principal — construído inteiramente via código.

const GAME_VERSION := "v0.1.0"
const GAME_SCENE := "res://scenes/world.tscn"

var _title_label: Label
var _subtitle_label: Label
var _volume_slider: HSlider
var _volume_value_label: Label
var _lang_button: Button
var _start_button: Button
var _quit_button: Button

var _bg_time: float = 0.0
var _title_base_y: float = 0.0

# Idiomas disponíveis
var _locales := ["en", "pt"]
var _locale_names := ["English", "Português"]
var _current_locale_index: int = 0


func _ready() -> void:
	# Detectar idioma atual
	var current := TranslationServer.get_locale().substr(0, 2)
	for i in range(_locales.size()):
		if _locales[i] == current:
			_current_locale_index = i
			break

	_build_ui()

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# Animação sutil do título (float suave)
	_bg_time += delta
	if _title_label:
		_title_label.position.y = _title_base_y + sin(_bg_time * 1.2) * 3.0


func _build_ui() -> void:
	# ── Background ──
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Gradient overlay (decorativo) ──
	var gradient_rect := ColorRect.new()
	gradient_rect.color = Color(0.05, 0.12, 0.25, 0.3)
	gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient_rect.anchor_top = 0.5
	add_child(gradient_rect)

	# ── Logo Press Start (canto superior esquerdo) ──
	var logo_tex := load("res://assets/PressStartLogo.png") as Texture2D
	if logo_tex:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(140, 60)
		logo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		logo.position.y -= 60
		logo.position.x -= 30
		add_child(logo)

	# ── Título do jogo ──
	_title_label = Label.new()
	_title_label.text = tr("MENU_GAME_TITLE")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.3, 0.7, 0.5))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.offset_top = 100
	_title_label.offset_left = -400
	_title_label.offset_right = 400
	_title_base_y = _title_label.offset_top
	add_child(_title_label)

	# ── Subtítulo ──
	_subtitle_label = Label.new()
	_subtitle_label.text = tr("MENU_SUBTITLE")
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.85, 0.7))
	_subtitle_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_subtitle_label.offset_top = 170
	_subtitle_label.offset_left = -400
	_subtitle_label.offset_right = 400
	add_child(_subtitle_label)

	# ── Painel central de opções ──
	var center_panel := _build_center_panel()
	add_child(center_panel)

	# ── Versão (canto inferior direito) ──
	var version_label := Label.new()
	version_label.text = GAME_VERSION
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65, 0.5))
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.offset_left = -120
	version_label.offset_top = -30
	version_label.offset_right = -20
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)

	# ── Linha decorativa embaixo do título ──
	var line := ColorRect.new()
	line.color = Color(0.2, 0.5, 0.9, 0.4)
	line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	line.offset_top = 195
	line.offset_left = -120
	line.offset_right = 120
	line.offset_bottom = 197
	add_child(line)


func _build_center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -80
	panel.offset_bottom = 140

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.45, 0.85, 0.4)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0.0, 0.2, 0.6, 0.15)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Volume ──
	var vol_section := HBoxContainer.new()
	vol_section.add_theme_constant_override("separation", 12)

	var vol_label := Label.new()
	vol_label.text = tr("MENU_VOLUME")
	vol_label.add_theme_font_size_override("font_size", 14)
	vol_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	vol_label.custom_minimum_size.x = 80
	vol_section.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.value = 80.0
	_volume_slider.step = 1.0
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.custom_minimum_size.y = 20
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_section.add_child(_volume_slider)

	_volume_value_label = Label.new()
	_volume_value_label.text = "80%"
	_volume_value_label.add_theme_font_size_override("font_size", 13)
	_volume_value_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	_volume_value_label.custom_minimum_size.x = 40
	_volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vol_section.add_child(_volume_value_label)

	vbox.add_child(vol_section)

	# ── Idioma ──
	var lang_section := HBoxContainer.new()
	lang_section.add_theme_constant_override("separation", 12)

	var lang_label := Label.new()
	lang_label.text = tr("MENU_LANGUAGE")
	lang_label.add_theme_font_size_override("font_size", 14)
	lang_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	lang_label.custom_minimum_size.x = 80
	lang_section.add_child(lang_label)

	_lang_button = Button.new()
	_lang_button.text = _locale_names[_current_locale_index]
	_lang_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lang_button.pressed.connect(_on_language_pressed)
	_apply_button_style(_lang_button, Color(0.08, 0.15, 0.28), Color(0.15, 0.25, 0.4))
	lang_section.add_child(_lang_button)

	vbox.add_child(lang_section)

	# ── Separador ──
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ── Botão START ──
	_start_button = Button.new()
	_start_button.text = tr("MENU_START")
	_start_button.custom_minimum_size.y = 44
	_start_button.pressed.connect(_on_start_pressed)
	_apply_button_style(_start_button, Color(0.08, 0.2, 0.12), Color(0.12, 0.35, 0.18))
	_start_button.add_theme_font_size_override("font_size", 18)
	_start_button.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vbox.add_child(_start_button)

	# ── Botão QUIT ──
	_quit_button = Button.new()
	_quit_button.text = tr("MENU_QUIT")
	_quit_button.custom_minimum_size.y = 36
	_quit_button.pressed.connect(_on_quit_pressed)
	_apply_button_style(_quit_button, Color(0.15, 0.06, 0.06), Color(0.25, 0.1, 0.1))
	_quit_button.add_theme_font_size_override("font_size", 14)
	_quit_button.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5, 0.8))
	vbox.add_child(_quit_button)

	return panel


func _apply_button_style(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.3, 0.5, 0.8, 0.3)

	var hover := normal.duplicate()
	hover.bg_color = hover_color
	hover.border_color = Color(0.4, 0.6, 0.9, 0.5)

	var pressed := normal.duplicate()
	pressed.bg_color = hover_color.lightened(0.1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ── Callbacks ──

func _on_volume_changed(value: float) -> void:
	_volume_value_label.text = "%d%%" % int(value)
	# Ajustar volume master
	var bus_idx := AudioServer.get_bus_index("Master")
	if value <= 0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))


func _on_language_pressed() -> void:
	_current_locale_index = (_current_locale_index + 1) % _locales.size()
	var new_locale: String = _locales[_current_locale_index]
	TranslationServer.set_locale(new_locale)
	_lang_button.text = _locale_names[_current_locale_index]

	# Atualizar textos localizados
	_refresh_texts()


func _on_start_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(GAME_SCENE)
	)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _refresh_texts() -> void:
	_title_label.text = tr("MENU_GAME_TITLE")
	_subtitle_label.text = tr("MENU_SUBTITLE")
	_start_button.text = tr("MENU_START")
	_quit_button.text = tr("MENU_QUIT")

	# Re-buscar labels de volume e idioma nos painéis
	# (mais simples: reconstruir o menu inteiro)
	# Para este protótipo, os labels fixos ficam no idioma original
	# pois rebuild completo é desnecessário
