import SpriteKit
import UIKit

final class Player: SKShapeNode {
    enum AppearanceType: CaseIterable {
        case normal     // 普通
        case hat        // 戴帽子
        case glasses    // 戴眼镜
    }

    enum PlayerState {
        case idle      // 正常
        case running   // 跑动中
        case stunned   // 眩晕（被棒子/枪/炸弹击中）
        case downed    // 倒地（被钩索/飞铲绊倒）
    }

    let index: Int
    let isMainPlayer: Bool
    let playerColor: UIColor
    let appearance: AppearanceType

    private(set) var state: PlayerState = .idle
    private var stateTimer: TimeInterval = 0
    private(set) var isSprinting: Bool = false
    private var sprintTimer: TimeInterval = 0
    private(set) var inventory: [Item.ItemType] = []
    let maxInventorySize = 2

    // Shield
    private(set) var hasShield: Bool = false
    private var shieldHitsRemaining: Int = 0
    private var shieldTimer: TimeInterval = 0
    private var shieldEffect: SKShapeNode?

    init(index: Int, color: UIColor, isMainPlayer: Bool, appearance: AppearanceType = .normal) {
        self.index = index
        self.isMainPlayer = isMainPlayer
        self.playerColor = color
        self.appearance = appearance
        super.init()

        setupAppearance()
        zPosition = 10
        name = "player_\(index)"

        let physicsRadius: CGFloat = 20
        physicsBody = SKPhysicsBody(circleOfRadius: physicsRadius)
        physicsBody?.isDynamic = true
        physicsBody?.mass = 1.0
        physicsBody?.friction = 0.2
        physicsBody?.restitution = 0.35
        physicsBody?.linearDamping = 2.2
        physicsBody?.allowsRotation = false

        physicsBody?.categoryBitMask = PhysicsCategory.player
        physicsBody?.collisionBitMask = PhysicsCategory.player | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.player

        if isMainPlayer {
            addMainPlayerIndicators()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setState(_ newState: PlayerState, duration: TimeInterval = 0) {
        // 先清除旧状态效果
        removeStateEffects()

        state = newState
        stateTimer = duration

        // 添加新状态效果
        switch newState {
        case .stunned:
            addStunnedEffect()
        case .downed:
            addDownedEffect()
        default:
            break
        }
    }

    func updateState(deltaTime: TimeInterval) {
        guard stateTimer > 0 else { return }
        stateTimer -= deltaTime
        if stateTimer <= 0 {
            stateTimer = 0
            state = .idle
            removeStateEffects()
        }
    }

    func startSprint(duration: TimeInterval) {
        isSprinting = true
        sprintTimer = duration
    }

    func updateSprint(deltaTime: TimeInterval) {
        guard isSprinting else { return }
        sprintTimer -= deltaTime
        if sprintTimer <= 0 {
            sprintTimer = 0
            isSprinting = false
        }
    }

    func activateShield(duration: TimeInterval, hits: Int) {
        hasShield = true
        shieldHitsRemaining = hits
        shieldTimer = duration
        addShieldEffect()
    }

    func updateShield(deltaTime: TimeInterval) {
        guard hasShield else { return }
        shieldTimer -= deltaTime
        if shieldTimer <= 0 {
            deactivateShield()
        }
    }

    func absorbHit() -> Bool {
        guard hasShield else { return false }
        shieldHitsRemaining -= 1

        // 盾牌闪烁效果
        if let shield = shieldEffect {
            let flash = SKAction.sequence([
                SKAction.run { shield.strokeColor = .white },
                SKAction.wait(forDuration: 0.1),
                SKAction.run { shield.strokeColor = .cyan }
            ])
            shield.run(flash)
        }

        if shieldHitsRemaining <= 0 {
            deactivateShield()
        }
        return true
    }

    func canPickupItem() -> Bool {
        return inventory.count < maxInventorySize
    }

    func pickupItem(_ type: Item.ItemType) -> Bool {
        guard canPickupItem() else { return false }
        inventory.append(type)
        return true
    }

    func dropItem(at index: Int) -> Item.ItemType? {
        guard index >= 0 && index < inventory.count else { return nil }
        return inventory.remove(at: index)
    }

    func useItem(at index: Int) -> Item.ItemType? {
        guard index >= 0 && index < inventory.count else { return nil }
        return inventory.remove(at: index)
    }

    func clearInventory() {
        inventory.removeAll()
    }

    func clearShield() {
        deactivateShield()
    }

    var canMove: Bool {
        state == .idle || state == .running
    }

    var canAct: Bool {
        state == .idle || state == .running
    }

    private func setupAppearance() {
        lineWidth = 0

        let headRadius: CGFloat = 10
        let head = SKShapeNode(circleOfRadius: headRadius)
        head.fillColor = playerColor
        head.strokeColor = .black
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 10)
        head.zPosition = 11
        head.name = "head"
        addChild(head)

        let bodySize = CGSize(width: 24, height: 22)
        let bodyRect = CGRect(origin: CGPoint(x: -bodySize.width / 2, y: -bodySize.height - 2), size: bodySize)
        let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        let body = SKShapeNode(path: bodyPath)
        body.fillColor = playerColor
        body.strokeColor = .black
        body.lineWidth = 2
        body.zPosition = 11
        body.name = "body"
        addChild(body)

        addAppearanceAccessories()
    }

    private func addAppearanceAccessories() {
        switch appearance {
        case .normal:
            break
        case .hat:
            // 添加一个小帽子（三角形或半圆）在头顶
            let hatPath = CGMutablePath()
            hatPath.move(to: CGPoint(x: -8, y: 18))
            hatPath.addLine(to: CGPoint(x: 8, y: 18))
            hatPath.addLine(to: CGPoint(x: 0, y: 30))
            hatPath.closeSubpath()
            let hat = SKShapeNode(path: hatPath)
            hat.fillColor = .brown
            hat.strokeColor = .black
            hat.lineWidth = 1
            hat.zPosition = 12
            hat.name = "hat"
            addChild(hat)
        case .glasses:
            // 添加眼镜（两个小圆圈连线）
            let glasses = SKShapeNode()
            let glassesPath = CGMutablePath()
            glassesPath.addEllipse(in: CGRect(x: -9, y: 7, width: 7, height: 7))
            glassesPath.addEllipse(in: CGRect(x: 2, y: 7, width: 7, height: 7))
            glassesPath.move(to: CGPoint(x: -2, y: 10))
            glassesPath.addLine(to: CGPoint(x: 2, y: 10))
            glasses.path = glassesPath
            glasses.strokeColor = .black
            glasses.lineWidth = 1.5
            glasses.fillColor = .clear
            glasses.zPosition = 12
            glasses.name = "glasses"
            addChild(glasses)
        }
    }

    private func addMainPlayerIndicators() {
        let ring = SKShapeNode(circleOfRadius: 26)
        ring.strokeColor = .white
        ring.lineWidth = 4
        ring.glowWidth = 4
        ring.fillColor = .clear
        ring.zPosition = 100
        ring.name = "youRing"
        addChild(ring)

        let you = SKLabelNode(text: "YOU")
        you.fontSize = 14
        you.fontColor = .white
        you.position = CGPoint(x: 0, y: 34)
        you.zPosition = 101
        you.name = "youLabel"
        addChild(you)

        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: -10, y: 46))
        arrowPath.addLine(to: CGPoint(x: 10, y: 46))
        arrowPath.addLine(to: CGPoint(x: 0, y: 70))
        arrowPath.closeSubpath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .white
        arrow.strokeColor = .black
        arrow.lineWidth = 2
        arrow.zPosition = 102
        arrow.name = "youArrow"
        addChild(arrow)
    }

    private func removeStateEffects() {
        childNode(withName: "stunnedEffect")?.removeFromParent()
        childNode(withName: "downedEffect")?.removeFromParent()
        zRotation = 0
    }

    private func addShieldEffect() {
        removeShieldEffect()

        let shield = SKShapeNode(circleOfRadius: 32)
        shield.fillColor = SKColor.cyan.withAlphaComponent(0.2)
        shield.strokeColor = .cyan
        shield.lineWidth = 3
        shield.glowWidth = 5
        shield.zPosition = 50
        shield.name = "shieldEffect"
        addChild(shield)
        shieldEffect = shield

        // 旋转动画
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
        shield.run(SKAction.repeatForever(rotate))
    }

    private func removeShieldEffect() {
        shieldEffect?.removeFromParent()
        shieldEffect = nil
    }

    private func deactivateShield() {
        hasShield = false
        shieldHitsRemaining = 0
        shieldTimer = 0
        removeShieldEffect()
    }

    private func addStunnedEffect() {
        let container = SKNode()
        container.name = "stunnedEffect"
        container.position = CGPoint(x: 0, y: 30)
        container.zPosition = 200

        let orbitRadius: CGFloat = 12
        let circleCount = 3
        for i in 0..<circleCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(circleCount))
            let circle = SKShapeNode(circleOfRadius: 4)
            circle.fillColor = .yellow
            circle.strokeColor = .clear
            circle.position = CGPoint(x: cos(angle) * orbitRadius, y: sin(angle) * orbitRadius)
            circle.zPosition = 201
            container.addChild(circle)
        }

        let rotate = SKAction.rotate(byAngle: 2 * .pi, duration: 2.0)
        container.run(SKAction.repeatForever(rotate))
        addChild(container)
    }

    private func addDownedEffect() {
        zRotation = .pi / 2

        let zzz = SKLabelNode(text: "Zzz")
        zzz.name = "downedEffect"
        zzz.fontName = "Helvetica-Bold"
        zzz.fontSize = 16
        zzz.fontColor = .white
        zzz.position = CGPoint(x: 0, y: 26)
        zzz.zPosition = 200
        addChild(zzz)
    }
}
