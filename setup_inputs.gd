extends SceneTree

func _init() -> void:
	print("⚙️ Configurando Inputs do Godot...")

	# 1. Configurar FIRE (Botão 0 / A / Espaço)
	var fire_action = "cannon_fire"
	if not ProjectSettings.has_setting("input/" + fire_action):
		ProjectSettings.set_setting("input/" + fire_action, {"deadzone": 0.2, "events": []})
	
	var fire_events = ProjectSettings.get_setting("input/" + fire_action)["events"]
	
	var has_joy_a = false
	for ev in fire_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			has_joy_a = true
	
	if not has_joy_a:
		var joy_btn_a = InputEventJoypadButton.new()
		joy_btn_a.button_index = JOY_BUTTON_A
		fire_events.append(joy_btn_a)
		var setting = ProjectSettings.get_setting("input/" + fire_action)
		setting["events"] = fire_events
		ProjectSettings.set_setting("input/" + fire_action, setting)


	# 2. Configurar SHIFT (Botão 1 / B / Shift Esquerdo)
	var shift_action = "cannon_shift"
	if not ProjectSettings.has_setting("input/" + shift_action):
		var events = []
		var key_shift = InputEventKey.new()
		key_shift.physical_keycode = KEY_SHIFT
		
		var joy_btn_b = InputEventJoypadButton.new()
		joy_btn_b.button_index = JOY_BUTTON_B
		
		events.append(key_shift)
		events.append(joy_btn_b)
		
		ProjectSettings.set_setting("input/" + shift_action, {"deadzone": 0.2, "events": events})


	# Salvar
	var err = ProjectSettings.save()
	if err == OK:
		print("✅ Inputs salvos com sucesso no project.godot!")
	else:
		print("❌ Erro ao salvar Inputs: ", err)

	quit()
