//
//  MapManager.swift
//  MazeRumble
//
//  Created by ChatGPT on 2025-??-??.
//

import SpriteKit

final class MapManager {

    private unowned let scene: SKScene
    private let worldNode: SKNode
    private let worldSize: CGSize

    var gates: [SKShapeNode] = []

    init(scene: SKScene, worldNode: SKNode, worldSize: CGSize) {
        self.scene = scene
        self.worldNode = worldNode
        self.worldSize = worldSize
    }

    private var worldCenter: CGPoint {
        CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
    }

    private var wallData: [[CGFloat]] {
        let w = worldSize.width
        let h = worldSize.height
        return [
            [w * 0.5, h * 0.55, w * 0.6, 24],
            [w * 0.5, h * 0.42, w * 0.55, 24],
            [w * 0.35, h * 0.68, 24, h * 0.26],
            [w * 0.65, h * 0.32, 24, h * 0.28],
            [w * 0.2, h * 0.5, 180, 24],
            [w * 0.8, h * 0.5, 180, 24],
            [w * 0.5, h * 0.75, 280, 24],
            [w * 0.5, h * 0.25, 280, 24],
            [w * 0.25, h * 0.25, 24, 240],
            [w * 0.75, h * 0.75, 24, 240],
            [w * 0.5, h * 0.62, 180, 24],
            [w * 0.58, h * 0.18, 200, 24]
        ]
    }

    func createBorder() {
        scene.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
        scene.physicsBody?.friction = 0.0
    }

    func createMaze() {
        for data in wallData {
            let wallSize = CGSize(width: data[2], height: data[3])
            let wall = SKShapeNode(rectOf: wallSize)
            wall.fillColor = SKColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
            wall.strokeColor = .black
            wall.lineWidth = 2
            wall.position = CGPoint(x: data[0], y: data[1])
            wall.zPosition = 5
            wall.name = "wall"

            wall.physicsBody = SKPhysicsBody(rectangleOf: wallSize)
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.friction = 0.3
            wall.physicsBody?.restitution = 0.2
            wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            wall.physicsBody?.collisionBitMask = PhysicsCategory.player
            wall.physicsBody?.contactTestBitMask = 0

            worldNode.addChild(wall)
        }
    }

    func createCenterZone() {
        let center = worldCenter

        let zone = SKShapeNode(circleOfRadius: GameConfig.centerZoneRadius)
        zone.fillColor = .yellow
        zone.strokeColor = .orange
        zone.lineWidth = 4
        zone.alpha = 0.30
        zone.position = center
        zone.zPosition = 1
        zone.name = "centerZone"
        worldNode.addChild(zone)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 1.0),
            SKAction.scale(to: 1.0, duration: 1.0)
        ])
        zone.run(.repeatForever(pulse))

        let label = SKLabelNode(text: "目标区")
        label.fontSize = 26
        label.fontColor = .white
        label.position = center
        label.zPosition = 2
        worldNode.addChild(label)
    }

    func createGates() {
        gates.forEach { $0.removeFromParent() }
        gates.removeAll()

        let usableWidth = worldSize.width * 0.8
        let startX = (worldSize.width - usableWidth) / 2
        let y = worldSize.height - GameConfig.gateSize.height

        for i in 0..<GameConfig.gateCount {
            let gate = SKShapeNode(rectOf: GameConfig.gateSize, cornerRadius: 6)
            gate.fillColor = SKColor.green.withAlphaComponent(0.5)
            gate.strokeColor = SKColor.green
            gate.lineWidth = 3
            let x = startX + CGFloat(i) * (usableWidth / CGFloat(GameConfig.gateCount - 1))
            gate.position = CGPoint(x: x, y: y)
            gate.zPosition = 3
            gate.name = "gate_\(i)"

            let label = SKLabelNode(text: String(UnicodeScalar(65 + i)!)) // A-E
            label.fontColor = .white
            label.fontSize = 18
            label.verticalAlignmentMode = .center
            label.position = .zero
            gate.addChild(label)

            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.8),
                SKAction.fadeAlpha(to: 0.4, duration: 0.8)
            ])
            gate.run(.repeatForever(pulse))

            worldNode.addChild(gate)
            gates.append(gate)
        }
    }
}
