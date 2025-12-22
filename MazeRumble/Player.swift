import SpriteKit
import UIKit

final class Player: SKShapeNode {
    enum PlayerState {
        case idle      // 正常
        case running   // 跑动中
        case stunned   // 眩晕（被棒子/枪/炸弹击中）
        case downed    // 倒地（被钩索/飞铲绊倒）
    }

    let index: Int
    let isMainPlayer: Bool
    let playerColor: UIColor

    private(set) var state: PlayerState = .idle
    private var stateTimer: TimeInterval = 0

    init(index: Int, color: UIColor, isMainPlayer: Bool) {
        self.index = index
        self.isMainPlayer = isMainPlayer
        self.playerColor = color
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
        state = newState
        stateTimer = duration
    }

    func updateState(deltaTime: TimeInterval) {
        guard stateTimer > 0 else { return }
        stateTimer -= deltaTime
        if stateTimer <= 0 {
            stateTimer = 0
            state = .idle
        }
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
}
