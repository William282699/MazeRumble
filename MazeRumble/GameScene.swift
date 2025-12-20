//
//  GameScene.swift
//  MazeRumble
//
//  Created by Yuqiao Huang on 2025-12-19.
//

import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    enum Team {
        case player
        case bot
    }

    // MARK: - Physics Category
    struct PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let wall: UInt32   = 1 << 1
    }

    // MARK: - 游戏对象
    private var players: [SKShapeNode] = []          // 8个玩家（0号是你）
    private var spawnPositions: [CGPoint] = []       // 出生点
    private var core: SKShapeNode?                   // 核心物品
    private var coreHolder: SKShapeNode?             // 谁拿着核心

    // MARK: - 控制（虚拟摇杆）
    private var joystick: SKShapeNode?
    private var joystickKnob: SKShapeNode?
    private var moveDirection = CGVector.zero
    private var isTouching = false

    // MARK: - UI
    private var scoreBoardLabel: SKLabelNode?
    private var timerLabel: SKLabelNode?
    private var hintLabel: SKLabelNode?

    private var roundTimeRemaining: TimeInterval = 60
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - 游戏状态
    private var playerScore = 0
    private var botScore = 0
    private let targetScore = 3

    private let roundDuration: TimeInterval = 60
    private var isRoundActive = false
    private var isMatchOver = false
    private var roundIndex = 0

    // MARK: - 参数（易调）
    private let centerZoneRadius: CGFloat = 100

    private let joystickBaseRadius: CGFloat = 70
    private let joystickKnobRadius: CGFloat = 35
    private let joystickTouchRadius: CGFloat = 260          // 左下角允许触摸区域半径（更宽松）
    private let joystickDeadZone: CGFloat = 10              // 摇杆死区

    private let playerMaxSpeed: CGFloat = 230               // 你最大速度
    private let botMaxSpeed: CGFloat = 200                  // Bot 最大速度
    private let accelLerp: CGFloat = 0.25                   // 速度插值系数（越大越跟手，0.15~0.30）
    private let botAccelLerp: CGFloat = 0.18

    private let dropImpulseThreshold: CGFloat = 50          // 撞击阈值：超过才掉核（只对玩家撞玩家生效）

    // MARK: - 初始化场景
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero

        createBorder()
        createMaze()
        createCenterZone()
        createCore()
        createPlayers()
        createJoystick()
        createUI()
        startRound()
    }

    // MARK: - 边界（和 size 对齐）
    private func createBorder() {
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        physicsBody?.friction = 0.0
    }

    // MARK: - 迷宫墙体
    private func createMaze() {
        let wallData: [[CGFloat]] = [
            [size.width * 0.3, size.height * 0.5, 20, 200],
            [size.width * 0.5, size.height * 0.7, 250, 20],
            [size.width * 0.7, size.height * 0.4, 20, 180],
            [size.width * 0.5, size.height * 0.3, 200, 20],
            [size.width * 0.2, size.height * 0.25, 150, 20],
            [size.width * 0.8, size.height * 0.65, 120, 20],
        ]

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

            addChild(wall)
        }
    }

    // MARK: - 中心区域
    private func createCenterZone() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let zone = SKShapeNode(circleOfRadius: centerZoneRadius)
        zone.fillColor = .yellow
        zone.strokeColor = .orange
        zone.lineWidth = 4
        zone.alpha = 0.30
        zone.position = center
        zone.zPosition = 1
        zone.name = "centerZone"
        addChild(zone)

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
        addChild(label)
    }

    // MARK: - 核心
    private func createCore() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // ✅ 自适应：不要固定 +150（竖屏宽很窄时容易顶到边上）
        let offset = min(size.width, size.height) * 0.28

        let c = SKShapeNode(rectOf: CGSize(width: 30, height: 30))
        c.fillColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        c.strokeColor = .white
        c.lineWidth = 3
        c.zRotation = .pi / 4
        c.position = CGPoint(x: center.x, y: center.y + offset)
        c.zPosition = 20
        c.name = "core"
        c.glowWidth = 10

        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
        c.run(.repeatForever(rotate))

        addChild(c)
        core = c
    }

    // MARK: - 玩家
    private func createPlayers() {
        let colors: [UIColor] = [
            .red, .blue, .green, .yellow,
            .orange, .purple, .cyan, .white
        ]

        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // ✅ 关键：自适应出生半径，避免 iPhone 竖屏时生成在边界外被挤成一坨
        let spawnRadius: CGFloat = min(size.width, size.height) * 0.34

        spawnPositions.removeAll()
        players.removeAll()

        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let x = center.x + cos(angle) * spawnRadius
            let y = center.y + sin(angle) * spawnRadius
            let spawn = CGPoint(x: x, y: y)
            spawnPositions.append(spawn)

            let p = SKShapeNode(circleOfRadius: 20)
            p.fillColor = colors[i]
            p.strokeColor = .black
            p.lineWidth = 2
            p.position = spawn
            p.zPosition = 10
            p.name = "player_\(i)"

            p.physicsBody = SKPhysicsBody(circleOfRadius: 20)
            p.physicsBody?.isDynamic = true
            p.physicsBody?.mass = 1.0
            p.physicsBody?.friction = 0.2
            p.physicsBody?.restitution = 0.35
            p.physicsBody?.linearDamping = 2.2
            p.physicsBody?.allowsRotation = false

            p.physicsBody?.categoryBitMask = PhysicsCategory.player
            p.physicsBody?.collisionBitMask = PhysicsCategory.player | PhysicsCategory.wall
            p.physicsBody?.contactTestBitMask = PhysicsCategory.player   // 只关心玩家撞玩家（用于掉核判断）

            addChild(p)
            players.append(p)
        }

        // ✅ 0号玩家是你：加 “YOU” + 光环
        if let me = players.first {
            let ring = SKShapeNode(circleOfRadius: 26)
            ring.strokeColor = .white
            ring.lineWidth = 3
            ring.glowWidth = 4
            ring.fillColor = .clear
            ring.zPosition = 100
            ring.name = "youRing"
            me.addChild(ring)

            let you = SKLabelNode(text: "YOU")
            you.fontSize = 14
            you.fontColor = .white
            you.position = CGPoint(x: 0, y: 34)
            you.zPosition = 101
            you.name = "youLabel"
            me.addChild(you)
        }
    }

    // MARK: - 虚拟摇杆
    private func createJoystick() {
        let base = SKShapeNode(circleOfRadius: joystickBaseRadius)
        base.fillColor = SKColor.gray.withAlphaComponent(0.35)
        base.strokeColor = .white
        base.lineWidth = 2
        base.position = CGPoint(x: 110, y: 130)
        base.zPosition = 200
        addChild(base)
        joystick = base

        let knob = SKShapeNode(circleOfRadius: joystickKnobRadius)
        knob.fillColor = SKColor.white.withAlphaComponent(0.65)
        knob.strokeColor = .black
        knob.lineWidth = 2
        knob.position = base.position
        knob.zPosition = 201
        addChild(knob)
        joystickKnob = knob
    }

    // MARK: - UI
    private func createUI() {
        let board = SKLabelNode(text: "玩家 0 : 0 Bot")
        board.fontSize = 26
        board.fontColor = .white
        board.position = CGPoint(x: size.width / 2, y: size.height - 42)
        board.zPosition = 300
        addChild(board)
        scoreBoardLabel = board

        let timer = SKLabelNode(text: "01:00")
        timer.fontSize = 30
        timer.fontColor = .yellow
        timer.position = CGPoint(x: size.width / 2, y: size.height - 78)
        timer.zPosition = 300
        addChild(timer)
        timerLabel = timer

        let hint = SKLabelNode(text: "抢到核心，带回中心区！")
        hint.fontSize = 18
        hint.fontColor = .yellow
        hint.position = CGPoint(x: size.width / 2, y: size.height - 108)
        hint.zPosition = 300
        addChild(hint)
        hintLabel = hint
    }

    // MARK: - 触摸（更宽松：左下角区域即可启动摇杆）
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isMatchOver, let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if let base = joystick {
            let d = hypot(loc.x - base.position.x, loc.y - base.position.y)
            if d <= joystickTouchRadius || (loc.x < size.width * 0.55 && loc.y < size.height * 0.5) {
                isTouching = true
                updateJoystick(with: loc)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isMatchOver, isTouching, let touch = touches.first else { return }
        updateJoystick(with: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        resetJoystick()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        resetJoystick()
    }

    private func updateJoystick(with location: CGPoint) {
        guard let base = joystick, let knob = joystickKnob else { return }

        let dx = location.x - base.position.x
        let dy = location.y - base.position.y
        let dist = hypot(dx, dy)

        let maxDist = joystickBaseRadius

        if dist <= maxDist {
            knob.position = location
        } else {
            let a = atan2(dy, dx)
            knob.position = CGPoint(x: base.position.x + cos(a) * maxDist,
                                   y: base.position.y + sin(a) * maxDist)
        }

        if dist < joystickDeadZone {
            moveDirection = .zero
        } else {
            let nx = dx / max(dist, 0.0001)
            let ny = dy / max(dist, 0.0001)
            moveDirection = CGVector(dx: nx, dy: ny)
        }
    }

    private func resetJoystick() {
        guard let base = joystick, let knob = joystickKnob else { return }
        knob.run(.move(to: base.position, duration: 0.08))
        moveDirection = .zero
    }

    // MARK: - 每帧更新
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard isRoundActive, !isMatchOver else { return }

        roundTimeRemaining = max(0, roundTimeRemaining - dt)
        updateTimerLabel()

        if roundTimeRemaining <= 0 {
            endRound(winner: nil)
            return
        }

        updatePlayerMovement()
        updateBotAI()
        checkCorePickup()
        checkWinCondition()
    }

    // MARK: - 你（0号玩家）移动：目标速度插值
    private func updatePlayerMovement() {
        guard let me = players.first, let body = me.physicsBody else { return }

        let desired = CGVector(dx: moveDirection.dx * playerMaxSpeed,
                              dy: moveDirection.dy * playerMaxSpeed)

        let vx = body.velocity.dx + (desired.dx - body.velocity.dx) * accelLerp
        let vy = body.velocity.dy + (desired.dy - body.velocity.dy) * accelLerp
        body.velocity = CGVector(dx: vx, dy: vy)
    }

    // MARK: - Bot AI：追核心/追持有者
    private func updateBotAI() {
        guard let c = core else { return }

        for i in 1..<players.count {
            let bot = players[i]
            guard let body = bot.physicsBody else { continue }

            let target: CGPoint
            if let holder = coreHolder, holder != bot {
                target = holder.position
            } else {
                target = c.position
            }

            let dx = target.x - bot.position.x
            let dy = target.y - bot.position.y
            let dist = hypot(dx, dy)

            var dir = CGVector.zero
            if dist > 20 {
                dir = CGVector(dx: dx / dist, dy: dy / dist)
            }

            let desired = CGVector(dx: dir.dx * botMaxSpeed,
                                  dy: dir.dy * botMaxSpeed)

            let vx = body.velocity.dx + (desired.dx - body.velocity.dx) * botAccelLerp
            let vy = body.velocity.dy + (desired.dy - body.velocity.dy) * botAccelLerp
            body.velocity = CGVector(dx: vx, dy: vy)
        }
    }

    // MARK: - 核心拾取
    private func checkCorePickup() {
        guard let c = core, coreHolder == nil else { return }

        for p in players {
            let d = hypot(p.position.x - c.position.x, p.position.y - c.position.y)
            if d < 36 {
                pickupCore(player: p)
                break
            }
        }
    }

    private func pickupCore(player: SKShapeNode) {
        coreHolder = player
        player.setScale(1.25)

        let glow = SKShapeNode(circleOfRadius: 32)
        glow.strokeColor = .yellow
        glow.lineWidth = 3
        glow.glowWidth = 10
        glow.fillColor = .clear
        glow.name = "glow"
        glow.zPosition = 200
        player.addChild(glow)

        let text = (player == players.first) ? "你拿到了核心！" : "Bot拿到了核心！"
        showMessage(text, color: (player == players.first) ? .green : .red)
    }

    private func dropCore(from player: SKShapeNode) {
        guard let c = core else { return }

        coreHolder = nil
        player.setScale(1.0)
        player.childNode(withName: "glow")?.removeFromParent()

        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist: CGFloat = 90
        c.position = CGPoint(x: player.position.x + cos(angle) * dist,
                            y: player.position.y + sin(angle) * dist)

        showMessage("核心掉落！", color: .orange)
    }

    // MARK: - 胜利条件：持核进入中心区立刻得分
    private func checkWinCondition() {
        guard let holder = coreHolder else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let d = hypot(holder.position.x - center.x, holder.position.y - center.y)
        if d < centerZoneRadius {
            let team: Team = (holder == players.first) ? .player : .bot
            endRound(winner: team)
        }
    }

    // MARK: - 碰撞：只允许“玩家撞玩家”导致掉核
    func didBegin(_ contact: SKPhysicsContact) {
        guard let holder = coreHolder else { return }

        guard let nodeA = contact.bodyA.node as? SKShapeNode,
              let nodeB = contact.bodyB.node as? SKShapeNode else { return }

        let isPlayerA = nodeA.name?.hasPrefix("player_") == true
        let isPlayerB = nodeB.name?.hasPrefix("player_") == true
        guard isPlayerA, isPlayerB else { return }

        let holderHit = (nodeA == holder || nodeB == holder)
        guard holderHit else { return }

        if contact.collisionImpulse > dropImpulseThreshold {
            dropCore(from: holder)
        }
    }

    // MARK: - 回合流程
    private func startRound() {
        guard !isMatchOver else { return }

        roundIndex += 1
        isRoundActive = true
        roundTimeRemaining = roundDuration
        lastUpdateTime = 0

        resetEntitiesForRound()
        updateTimerLabel()
        updateScoreBoard()

        showMessage("第\(roundIndex)回合开始", color: .cyan)
    }

    private func endRound(winner: Team?) {
        guard isRoundActive else { return }
        isRoundActive = false

        if let w = winner {
            switch w {
            case .player:
                playerScore += 1
                showMessage("玩家得分！", color: .green)
            case .bot:
                botScore += 1
                showMessage("Bot得分！", color: .red)
            }
        } else {
            showMessage("时间到，回合重置", color: .yellow)
        }

        updateScoreBoard()

        if playerScore >= targetScore || botScore >= targetScore {
            isMatchOver = true
            let finalText = (playerScore >= targetScore) ? "🎉 玩家阵营胜利！" : "🤖 Bot阵营胜利！"
            showMessage(finalText, color: (playerScore >= targetScore) ? .green : .red)
            return
        }

        // 2秒后下一回合（这2秒他们会停住，这是正常的）
        run(.sequence([
            .wait(forDuration: 2.0),
            .run { [weak self] in self?.startRound() }
        ]))
    }

    private func resetEntitiesForRound() {
        coreHolder = nil

        if let c = core {
            c.removeAllActions()
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let offset = min(size.width, size.height) * 0.28
            c.position = CGPoint(x: center.x, y: center.y + offset)
            if c.parent == nil { addChild(c) }
            c.zPosition = 20
            c.zRotation = .pi / 4
            c.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 2.0)))
        }

        for (idx, p) in players.enumerated() {
            if idx < spawnPositions.count { p.position = spawnPositions[idx] }
            p.setScale(1.0)
            p.childNode(withName: "glow")?.removeFromParent()
            if let body = p.physicsBody {
                body.velocity = .zero
                body.angularVelocity = 0
            }
        }
    }

    // MARK: - UI helpers
    private func updateScoreBoard() {
        scoreBoardLabel?.text = "玩家 \(playerScore) : \(botScore) Bot"
    }

    private func updateTimerLabel() {
        let minutes = Int(roundTimeRemaining) / 60
        let seconds = Int(roundTimeRemaining) % 60
        timerLabel?.text = String(format: "%02d:%02d", minutes, seconds)
    }

    private func showMessage(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontSize = 22
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: size.height - 135)
        label.zPosition = 400
        addChild(label)

        label.run(.sequence([
            .fadeIn(withDuration: 0.05),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
    }
}
