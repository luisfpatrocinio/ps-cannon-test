# Guia do Controle Físico Padrão — Canhão de Projéteis

Este documento descreve as especificações atuais da aplicação e do firmware do controle físico BLE usado pelo jogo. O objetivo do projeto é fazer o ESP32 se comportar como um gamepad HID Bluetooth padrão, reconhecido nativamente pelo sistema operacional e pela Godot, sem depender de serial, JSON ou protocolos proprietários no lado do jogo.

Essa abordagem mantém a integração simples: o hardware aparece como joystick padrão, e a Godot consome os eventos via `Input Map` e APIs de joypad.

---

## Especificação da Aplicação

O controle físico implementa três entradas principais:

| Entrada física | Função no jogo | Saída HID |
| -------------- | -------------- | --------- |
| Potenciômetro  | Ajuste contínuo do ângulo do canhão | Eixo Y do analógico esquerdo |
| Botão FIRE     | Disparo do canhão | `BUTTON_1` |
| Botão SHIFT    | Modificador para altura / ação auxiliar | `BUTTON_2` |

No jogo, o eixo analógico é usado para posicionamento suave do ângulo, enquanto o botão de shift permite alterar a lógica de controle de altura conforme o script da cena.

---

## Componentes Necessários

### Essenciais

| Componente                                 | Qtd | Função no Jogo                                  | Pino ESP32 Atual | Mapeamento HID |
| ------------------------------------------ | --- | ----------------------------------------------- | ---------------- | -------------- |
| **Potenciômetro** (10kΩ)                   | 1   | Controlar o **ângulo** e a **altura** do canhão | GPIO4 (ADC)      | Left Thumb Y   |
| **Botão momentâneo** (tipo arcade)         | 1   | **Disparar** o canhão                           | GPIO18           | Button 1       |
| **Botão momentâneo** (tipo auxiliar)       | 1   | **Shift / Alternar**                            | GPIO19           | Button 2       |
| **ESP32 DevKit V1** (ou outro com BLE)     | 1   | Microcontrolador principal                      | —                | —              |
| **Cabo USB Micro-B**                       | 1   | Programação e alimentação                       | —                | —              |

### Opcionais

- Protoboard e jumpers.
- Capacitor cerâmico de `100nF` entre sinal do potenciômetro e GND para reduzir ruído.
- Case impressa em 3D.

---

## Esquema de Conexão Atual

```text
ESP32 DevKit V1
┌──────────────────┐
│                  │
│  GPIO4  (ADC) ◄──── Potenciômetro (pino central / sinal)
│  GPIO18      ◄──── Botão de Disparo
│  GPIO19      ◄──── Botão de Ação / Shift
│                  │
│  3.3V ───────────── VCC do potenciômetro
│  GND ────────────── GND comum (potenciômetro e botões)
│                  │
└──────────────────┘
```

> Atenção: os pinos ADC do ESP32 operam entre `0V` e `3.3V`. Os botões devem ser ligados entre o GPIO correspondente e o GND, usando `INPUT_PULLUP` no firmware.

> Observação prática: o firmware atual usa `GPIO4` para o potenciômetro porque esse é o cabeamento presente no hardware atual. Se houver ruído persistente, a melhor troca elétrica costuma ser migrar o potenciômetro para um pino ADC1 como `GPIO32` ou `GPIO33`.

---

## Dependência do Projeto

O projeto foi criado em PlatformIO e usa o próprio gerenciador de dependências do PlatformIO.

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
monitor_filters =
  colorize
  time
lib_deps =
  lemmingDev/ESP32-BLE-Gamepad
```

Biblioteca utilizada:

- [ESP32-BLE-Gamepad](https://github.com/lemmingDev/ESP32-BLE-Gamepad)

---

## Firmware Implementado

O firmware atual em `src/main.cpp` implementa:

1. Um gamepad BLE com nome `Canhao Controller`.
2. Dois botões HID:
   - `BUTTON_1` para disparo.
   - `BUTTON_2` para shift / alternância.
3. Um eixo analógico no `Left Thumb Y`.
4. Leitura periódica de entrada a cada `20 ms`.
5. Debounce de botões com `30 ms`.
6. Filtro de ruído do potenciômetro com múltiplas etapas.
7. Envio manual de relatório BLE apenas quando há mudança real.

### Estratégia atual de filtragem do potenciômetro

O eixo analógico foi endurecido para reduzir tremulação no jogo. O pipeline atual é:

1. Coleta de `7` amostras por leitura.
2. Uso de mediana para descartar picos espúrios.
3. Filtro exponencial com `alpha = 0.12`.
4. `Noise gate` no domínio bruto filtrado.
5. `Deadzone` central ampliada.
6. Histerese na saída HID para evitar microvariações.

Isso reduz jitter tanto no serial quanto dentro da Godot.

---

## Estratégia de Logs e Debug

O firmware foi ajustado para facilitar debug no `Serial Monitor` sem poluir a saída.

### Logs sempre ativos

- `[BOOT]`: inicialização, baud rate, pinos configurados e flags de log.
- `[BLE]`: estado de conexão e espera por host Bluetooth.
- `[BTN]`: eventos de pressionado/solto com timestamp em ms.

### Logs opcionais

- `[AXIS]`: valores bruto, filtrado e mapeado do eixo.
- `[STATUS]`: snapshot periódico do estado geral do controle.

Esses logs ficam desligados por padrão no código via:

- `ENABLE_AXIS_LOGS = false`
- `ENABLE_STATUS_LOGS = false`

Essa configuração foi escolhida para que pressionamentos de botão fiquem claramente visíveis no monitor serial, sem serem escondidos por spam do eixo analógico.

---

## Integração na Godot

Com o controle emparelhado nas configurações Bluetooth do sistema operacional, a engine reconhece o hardware nativamente.

### Mapeamento sugerido no Input Map

1. Em `Project > Project Settings > Input Map`, mapear `cannon_fire` para `Joypad Button 0`.
2. Mapear `cannon_shift` ou ação equivalente para `Joypad Button 1`.
3. Ler o eixo esquerdo Y do controle para dirigir o ângulo do canhão.

### Exemplo de integração com o script do canhão

```gdscript
# Exemplo de adaptação (como foi integrado no cannon.gd)
var last_joy_axis: float = 0.0

func _handle_analog_input() -> void:
    if not Input.get_connected_joypads().is_empty():
        var axis_val := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

        if abs(axis_val - last_joy_axis) > 0.02:
            last_joy_axis = axis_val
            var normalized_val := (-axis_val + 1.0) / 2.0

            current_angle = min_angle + normalized_val * (max_angle - min_angle)
            _apply_transforms()

func _handle_height_input(delta: float) -> void:
    if Input.is_action_pressed("cannon_shift"):
        current_height += height_speed * delta

    if current_height >= max_height:
        current_height = min_height

    _apply_transforms()
```

Esse modelo mantém o ângulo analógico suave e deixa a altura condicionada ao botão auxiliar.

---

## Mapeamento Físico Atual

| Função        | GPIO | HID          |
| ------------- | ---- | ------------ |
| Potenciômetro | 4    | Left Thumb Y |
| FIRE          | 18   | Button 1     |
| SHIFT         | 19   | Button 2     |

---

## Próxima Validação Recomendada

Após gravar o firmware no ESP32:

1. Abrir o `Serial Monitor` em `115200`.
2. Confirmar as mensagens `[BOOT]` e `[BLE]`.
3. Emparelhar o dispositivo Bluetooth `Canhao Controller`.
4. Pressionar `FIRE` e `SHIFT` para validar eventos `[BTN]`.
5. Se necessário, ativar temporariamente `ENABLE_AXIS_LOGS` para inspecionar o potenciômetro.
6. Validar na Godot o reconhecimento do eixo Y e dos botões 1 e 2.

---

## Resumo do Estado Atual

O projeto já está funcional como gamepad BLE via ESP32 e PlatformIO. O foco atual da implementação é:

- compatibilidade nativa com a Godot;
- debug simples pelo serial monitor;
- redução de ruído do potenciômetro no firmware;
- documentação sincronizada com o estado real do hardware e do código.
