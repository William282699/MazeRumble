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
    
    // MARK: - Items pickup
    static let itemPickupRange: CGFloat = 45   // 道具拾取范围

    // MARK: - Bomb
    static let bombThrowDistance: CGFloat = 150    // 炸弹投掷距离
    static let bombFuseTime: TimeInterval = 1.5    // 炸弹引爆时间
    static let bombExplosionRadius: CGFloat = 120  // 爆炸范围
    static let bombStunDuration: TimeInterval = 3.0 // 眩晕时间

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

    // MARK: - Actions
    static let pushRange: CGFloat = 60           // 推人范围
    static let pushForce: CGFloat = 300          // 推人力度（减小，轻推）
    static let pushCooldown: TimeInterval = 1.5  // 推人冷却

    static let tackleRange: CGFloat = 80         // 铲人范围
    static let tackleForce: CGFloat = 600        // 铲人力度（自己也会冲出去）
    static let tackleCooldown: TimeInterval = 2.0 // 铲人冷却
    static let tackleDownDuration: TimeInterval = 1.0  // 被铲倒地时间

    // MARK: - Dash (猛冲)
    static let dashForce: CGFloat = 1200         // 猛冲力度
    static let dashCooldown: TimeInterval = 3.0  // 猛冲冷却
    static let dashKnockbackForce: CGFloat = 500 // 撞人后对方被推开的力度
    static let dashKnockbackRange: CGFloat = 50  // 冲撞判定范围
    
    // MARK: - Sprint (快跑)
    static let sprintSpeedMultiplier: CGFloat = 1.8  // 快跑速度倍数
    static let sprintDuration: TimeInterval = 2.0    // 快跑持续时间
    static let sprintCooldown: TimeInterval = 5.0    // 快跑冷却

    // MARK: - Hook
    static let hookRange: CGFloat = 200           // 钩索射程
    static let hookSpeed: TimeInterval = 0.25     // 钩索飞行时间
    static let hookDownDuration: TimeInterval = 2.0 // 绊倒时间
    static let hookPullForce: CGFloat = 400       // 把人拉过来的力度

    // MARK: - Gun
    static let gunRange: CGFloat = 350            // 射程
    static let gunBulletSpeed: TimeInterval = 0.2 // 子弹飞行时间
    static let gunStunDuration: TimeInterval = 3.0 // 命中眩晕时间

    // MARK: - Shield
    static let shieldDuration: TimeInterval = 3.0  // 盾牌持续时间
    static let shieldHits: Int = 3                 // 可抵挡次数

    // MARK: - World / Camera
    static let worldScaleFactor: CGFloat = 3.0
    static let cameraLerp: CGFloat = 0.18
}
