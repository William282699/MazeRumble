import SpriteKit
import UIKit

final class Player: SKShapeNode {
    let index: Int
    let isMainPlayer: Bool

    init(index: Int, color: UIColor, isMainPlayer: Bool) {
        self.index = index
        self.isMainPlayer = isMainPlayer
        super.init()

        let radius: CGFloat = 20
        let circlePath = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        path = circlePath
        fillColor = color
        strokeColor = .black
        lineWidth = 2
        zPosition = 10
        name = "player_\(index)"

        physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody?.isDynamic = true
        physicsBody?.mass = 1.0
        physicsBody?.friction = 0.2
        physicsBody?.restitution = 0.35
        physicsBody?.linearDamping = 2.2
        physicsBody?.allowsRotation = false

        physicsBody?.categoryBitMask = GameScene.PhysicsCategory.player
        physicsBody?.collisionBitMask = GameScene.PhysicsCategory.player | GameScene.PhysicsCategory.wall
        physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.player

        if isMainPlayer {
            addMainPlayerIndicators()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
