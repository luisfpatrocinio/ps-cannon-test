# Guia do Controle ESP32 — Canhão de Projéteis

Este documento contém as orientações para construir um controle físico usando ESP32 para o jogo do canhão de projéteis.

---

## Componentes Necessários

### Essenciais

| #   | Componente                                 | Qtd | Função no Jogo                            | Pino ESP32 Sugerido |
| --- | ------------------------------------------ | --- | ----------------------------------------- | ------------------- |
| 1   | **Potenciômetro rotativo** (10kΩ)          | 1   | Controlar o **ângulo** do canhão (5°–80°) | GPIO34 (ADC)        |
| 2   | **Potenciômetro linear (slider)**          | 1   | Controlar a **altura** do canhão (0–5m)   | GPIO35 (ADC)        |
| 3   | **Potenciômetro rotativo** (10kΩ)          | 1   | Controlar a **potência** do disparo       | GPIO36 (ADC)        |
| 4   | **Botão momentâneo** (tipo arcade, grande) | 1   | **Disparar** o canhão                     | GPIO23 (Digital)    |
| 5   | **ESP32 DevKit V1**                        | 1   | Microcontrolador principal                | —                   |
| 6   | **Protoboard** ou **PCB perfurada**        | 1   | Montagem dos componentes                  | —                   |
| 7   | **Jumpers / fios**                         | ~15 | Conexões                                  | —                   |
| 8   | **Cabo USB Micro-B**                       | 1   | Alimentação + comunicação serial          | —                   |

### Opcionais (melhoram a experiência)

| Componente                       | Função                                                        |
| -------------------------------- | ------------------------------------------------------------- |
| LED RGB ou fita NeoPixel         | Feedback visual do estado (mirando / rastreando / retornando) |
| Buzzer piezoelétrico             | Som ao disparar                                               |
| Display OLED 0.96" I2C (SSD1306) | Mostrar parâmetros no controle                                |
| Botão extra                      | Reset / funcionalidade futura                                 |
| Case impresso em 3D              | Acabamento profissional para o controle                       |

---

## Esquema de Conexão

```
ESP32 DevKit V1
┌──────────────────┐
│                  │
│  GPIO34 (ADC) ◄──── Potenciômetro Ângulo (sinal)
│  GPIO35 (ADC) ◄──── Potenciômetro/Slider Altura (sinal)
│  GPIO36 (ADC) ◄──── Potenciômetro Potência (sinal)
│  GPIO23       ◄──── Botão de Disparo
│                  │
│  3.3V ───────────── VCC dos potenciômetros
│  GND ────────────── GND comum
│                  │
└──────────────────┘
```

> **Nota:** Os pinos ADC do ESP32 (GPIO32-39) aceitam tensão de 0V a 3.3V. Conecte cada potenciômetro entre 3.3V e GND, com o pino central (wiper) indo para o GPIO ADC correspondente.

> **Nota:** Use um resistor pull-up interno ou externo (10kΩ) no botão de disparo. O botão deve conectar o GPIO ao GND quando pressionado.

---

## Protocolo de Comunicação

### Opção Recomendada: Serial (USB)

A forma mais simples de comunicar ESP32 ↔ Godot é via **porta serial USB**.

#### Formato dos dados (ESP32 → Godot)

Enviar uma linha JSON a cada ~50ms (20 Hz):

```json
{ "a": 0.73, "h": 0.45, "p": 0.85, "f": 1 }
```

| Campo | Tipo            | Descrição                          |
| ----- | --------------- | ---------------------------------- |
| `a`   | float (0.0–1.0) | Ângulo normalizado                 |
| `h`   | float (0.0–1.0) | Altura normalizada                 |
| `p`   | float (0.0–1.0) | Potência normalizada               |
| `f`   | int (0 ou 1)    | Botão de disparo (1 = pressionado) |

#### Mapeamento no Godot

```
ângulo_real = min_angle + a * (max_angle - min_angle)   → 5° a 80°
altura_real = min_height + h * (max_height - min_height) → 0m a 5m
potencia_real = p * max_power                             → 0 a N
```

### Alternativas

| Método               | Vantagem                           | Desvantagem                     |
| -------------------- | ---------------------------------- | ------------------------------- |
| **Serial USB**       | Simples, confiável, baixa latência | Requer cabo                     |
| **WebSocket (WiFi)** | Sem fio                            | Requer rede WiFi, mais latência |
| **Bluetooth (BLE)**  | Sem fio, sem rede                  | Mais complexo de implementar    |

---

## Código Arduino — Estrutura Básica

```cpp
#include <Arduino.h>
#include <ArduinoJson.h>

// Pinos
const int PIN_ANGLE  = 34;
const int PIN_HEIGHT = 35;
const int PIN_POWER  = 36;
const int PIN_FIRE   = 23;

// Intervalo de envio (ms)
const unsigned long SEND_INTERVAL = 50;
unsigned long lastSend = 0;

// Debounce
bool lastFireState = false;

void setup() {
  Serial.begin(115200);
  pinMode(PIN_FIRE, INPUT_PULLUP);
}

void loop() {
  unsigned long now = millis();
  if (now - lastSend < SEND_INTERVAL) return;
  lastSend = now;

  // Ler potenciômetros (0-4095 → 0.0-1.0)
  float angle  = analogRead(PIN_ANGLE)  / 4095.0;
  float height = analogRead(PIN_HEIGHT) / 4095.0;
  float power  = analogRead(PIN_POWER)  / 4095.0;

  // Ler botão (active LOW com pull-up)
  bool firePressed = !digitalRead(PIN_FIRE);
  int fire = (firePressed && !lastFireState) ? 1 : 0;
  lastFireState = firePressed;

  // Enviar JSON
  StaticJsonDocument<128> doc;
  doc["a"] = round(angle  * 100) / 100.0;
  doc["h"] = round(height * 100) / 100.0;
  doc["p"] = round(power  * 100) / 100.0;
  doc["f"] = fire;

  serializeJson(doc, Serial);
  Serial.println();
}
```

---

## Dicas de Implementação

1. **Suavização ADC**: Use média móvel (ex: 8 samples) para evitar ruído nos potenciômetros
2. **Dead zones**: Ignore valores muito próximos de 0.0 e 1.0 (ex: < 0.02 ou > 0.98)
3. **Debounce do botão**: O código acima já implementa edge detection (envia `f:1` apenas no momento do clique)
4. **Baudrate**: Use 115200 tanto no ESP32 quanto no Godot
5. **Calibração**: Considere adicionar um modo de calibração que salve os valores min/max dos potenciômetros na EEPROM
