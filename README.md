# Trajectory Lab (PS Cannon Test)

A cannon prototype built in **Godot 4.6** with **Jolt Physics** for testing controller input mechanics and demonstrating projectile motion. The player adjusts the cannon's height and angle, then fires a ballistic projectile while the camera follows the action to show the flight distance at the point of impact.

## ✨ Features

- **Main Menu**: Fully functional main menu with options for volume control and language selection (English/Portuguese).
- **Physical Controls**: Adjustable cannon angle (5°–80°) and height (0–5m).
- **Realistic Physics**: Ballistic projectile with Jolt Physics integration.
- **Dynamic Camera System**: Four distinct states:
  - **Aiming**: Free look to aim
  - **Tracking**: Follows the projectile in mid-air
  - **Impact**: Freezes at the landing location, calculating and displaying the total distance in meters via a 3D Billboard.
  - **Returning**: Smooth transition back to the cannon
- **Interactive UI**: HUD with real-time parameter gauges, crosshairs, and contextual state indicators.
- **Hardware Integration**: Includes a guide for building a physical controller using an **ESP32**, potentiometers, and arcade buttons.

## 🎮 Controls

### Keyboard Defaults

| Key   | Action               |
| ----- | -------------------- |
| ↑ / ↓ | Adjust cannon angle  |
| W / S | Adjust cannon height |
| Space | Fire projectile      |

### Hardware Controller (ESP32)

You can build a custom physical controller for this game! Check out the [ESP32 Controller Guide](ESP32_CONTROLLER_GUIDE.md) in the project root for wiring diagrams and starter Arduino code using serial JSON communication.

## 🚀 Setup

1. Open the project in **Godot 4.6+** (Forward+ rendering).
2. Ensure you have the [Godot Jolt](https://github.com/godot-jolt/godot-jolt) physics extension installed and enabled if needed (the project uses Jolt by default).
3. Run with **F5** to start from the Main Menu.

## 🛠️ Tech Stack

- Godot 4.6 (Forward+)
- Jolt Physics 3D
- GDScript
- ESP32 (Hardware Controller)
