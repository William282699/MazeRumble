import Foundation
import CoreGraphics

struct GameConfig {
    // MARK: - Core interactions
    static let pickupDistance: CGFloat = 40
    static let dropHitsRequired = 3
    static let dropDistance: CGFloat = 80

    // MARK: - Items
    static let itemInterval: TimeInterval = 8
    static let maxItemsPerPlayer = 3

    // MARK: - Final dash
    static let finalDashTriggerDistance: CGFloat = 100
    static let finalDashDuration: TimeInterval = 5
    static let finalDashSpeedMultiplier: CGFloat = 1.5

    // MARK: - Gates
    static let gateCount = 5
    static let gateWinDistance: CGFloat = 50
    static let gateSize = CGSize(width: 40, height: 80)

    // MARK: - Timing
    static let gameTimeLimit: TimeInterval = 120

    // MARK: - Zones
    static let centerZoneRadius: CGFloat = 100

    // MARK: - Joystick
    static let joystickBaseRadius: CGFloat = 70
    static let joystickKnobRadius: CGFloat = 35
    static let joystickTouchRadius: CGFloat = 260
    static let joystickDeadZone: CGFloat = 10

    // MARK: - UI
    static let scoreBackgroundSize = CGSize(width: 320, height: 64)
    static let progressBarWidth: CGFloat = 150
    static let progressBarHeight: CGFloat = 12

    // MARK: - Movement
    static let playerMaxSpeed: CGFloat = 300
    static let botMaxSpeed: CGFloat = 220
    static let accelLerp: CGFloat = 0.25
    static let botAccelLerp: CGFloat = 0.18

    // MARK: - Physics
    static let dropImpulseThreshold: CGFloat = 50

    // MARK: - World / Camera
    static let worldScaleFactor: CGFloat = 3.0
    static let cameraLerp: CGFloat = 0.18
}
