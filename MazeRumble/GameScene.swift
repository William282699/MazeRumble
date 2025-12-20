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
    private var scoreBoardShadow: SKLabelNode?
    private var scoreBoardBackground: SKShapeNode?
    private var playerProgressTrack: SKShapeNode?
    private var botProgressTrack: SKShapeNode?
    private var playerProgressBar: SKSpriteNode?
    private var botProgressBar: SKSpriteNode?
    private var timerLabel: SKLabelNode?
    private var hintLabel: SKLabelNode?
    private var matchEndOverlay: SKNode?

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

    private let scoreBackgroundSize = CGSize(width: 320, height: 64)
    private let progressBarWidth: CGFloat = 150
    private let progressBarHeight: CGFloat = 12

    private let playerMaxSpeed: CGFloat = 230               // 你最大速度
    private let botMaxSpeed: CGFloat = 200                  // Bot 最大速度
    private let accelLerp: CGFloat = 0.25                   // 速度插值系数（越大越跟手，0.15~0.30）
    private let botAccelLerp: CGFloat = 0.18

    private let dropImpulseThreshold: CGFloat = 50          // 撞击阈值：超过才掉核（只对玩家撞玩家生效）

    // MARK: - 世界 / 相机
    private let worldScaleFactor: CGFloat = 3.0
    private var worldSize: CGSize = .zero
    private let worldNode = SKNode()
    private let uiNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let cameraLerp: CGFloat = 0.18

    // MARK: - 初始化场景
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero

        worldSize = CGSize(width: size.width * worldScaleFactor,
                           height: size.height * worldScaleFactor)

        addChild(worldNode)
        addChild(cameraNode)
        cameraNode.addChild(uiNode)
        camera = cameraNode
        uiNode.zPosition = 10_000

        createBorder()
        createMaze()
        createCenterZone()
        createCore()
        createPlayers()
        createJoystick()
        createUI()
        layoutUI()
        focusCameraInstantly()
        startRound()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutUI()
    }

    private var worldCenter: CGPoint {
        CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
    }

    // MARK: - 边界（和 size 对齐）
    private func createBorder() {
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
        physicsBody?.friction = 0.0
    }

    // MARK: - 迷宫墙体
    private func createMaze() {
        let w = worldSize.width
        let h = worldSize.height

        let wallData: [[CGFloat]] = [
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

    // MARK: - 中心区域
    private func createCenterZone() {
        let center = worldCenter

        let zone = SKShapeNode(circleOfRadius: centerZoneRadius)
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

    // MARK: - 核心
    private func createCore() {
        let center = worldCenter

        // ✅ 自适应：不要固定 +150（竖屏宽很窄时容易顶到边上）
        let offset = min(worldSize.width, worldSize.height) * 0.28

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

        worldNode.addChild(c)
        core = c
    }

    // MARK: - 玩家
    private func createPlayers() {
        let colors: [UIColor] = [
            .red, .blue, .green, .yellow,
            .orange, .purple, .cyan, .white
        ]

        let center = worldCenter

        // ✅ 关键：自适应出生半径，避免 iPhone 竖屏时生成在边界外被挤成一坨
        let spawnRadius: CGFloat = min(worldSize.width, worldSize.height) * 0.18

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

            worldNode.addChild(p)
            players.append(p)
        }

        // ✅ 0号玩家是你：加 “YOU” + 光环
        if let me = players.first {
            let ring = SKShapeNode(circleOfRadius: 26)
            ring.strokeColor = .white
            ring.lineWidth = 4
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
            me.addChild(arrow)
        }
    }

    // MARK: - 虚拟摇杆
    private func createJoystick() {
        let base = SKShapeNode(circleOfRadius: joystickBaseRadius)
        base.fillColor = SKColor.gray.withAlphaComponent(0.35)
        base.strokeColor = .white
        base.lineWidth = 2
        base.zPosition = 200
        uiNode.addChild(base)
        joystick = base

        let knob = SKShapeNode(circleOfRadius: joystickKnobRadius)
        knob.fillColor = SKColor.white.withAlphaComponent(0.65)
        knob.strokeColor = .black
        knob.lineWidth = 2
        knob.zPosition = 201
        uiNode.addChild(knob)
        joystickKnob = knob
    }

    // MARK: - UI
    private func createUI() {
        let bg = SKShapeNode(rectOf: scoreBackgroundSize, cornerRadius: 18)
        bg.fillColor = UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.78)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.85)
        bg.lineWidth = 2.5
        bg.zPosition = 298
        bg.name = "scoreBoardBackground"
        uiNode.addChild(bg)
        scoreBoardBackground = bg

        let shadow = SKLabelNode(text: "玩家 0 : 0 Bot")
        shadow.fontSize = 32
        shadow.fontName = "AvenirNext-Bold"
        shadow.fontColor = UIColor.black.withAlphaComponent(0.55)
        shadow.position = CGPoint(x: 0, y: -2)
        shadow.zPosition = 299
        uiNode.addChild(shadow)
        scoreBoardShadow = shadow

        let board = SKLabelNode(text: "玩家 0 : 0 Bot")
        board.fontSize = 32
        board.fontName = "AvenirNext-Bold"
        board.fontColor = .white
        board.zPosition = 300
        board.horizontalAlignmentMode = .center
        board.verticalAlignmentMode = .center
        uiNode.addChild(board)
        scoreBoardLabel = board

        let playerTrack = SKShapeNode(rectOf: CGSize(width: progressBarWidth, height: progressBarHeight), cornerRadius: progressBarHeight / 2)
        playerTrack.fillColor = UIColor.white.withAlphaComponent(0.12)
        playerTrack.strokeColor = UIColor.white.withAlphaComponent(0.35)
        playerTrack.lineWidth = 1.5
        playerTrack.zPosition = 299
        uiNode.addChild(playerTrack)
        playerProgressTrack = playerTrack

        let playerFill = SKSpriteNode(color: UIColor(red: 0.15, green: 0.85, blue: 0.35, alpha: 0.9),
                                      size: CGSize(width: progressBarWidth, height: progressBarHeight))
        playerFill.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        playerFill.zPosition = 300
        playerTrack.addChild(playerFill)
        playerProgressBar = playerFill

        let botTrack = SKShapeNode(rectOf: CGSize(width: progressBarWidth, height: progressBarHeight), cornerRadius: progressBarHeight / 2)
        botTrack.fillColor = UIColor.white.withAlphaComponent(0.12)
        botTrack.strokeColor = UIColor.white.withAlphaComponent(0.35)
        botTrack.lineWidth = 1.5
        botTrack.zPosition = 299
        uiNode.addChild(botTrack)
        botProgressTrack = botTrack

        let botFill = SKSpriteNode(color: UIColor(red: 0.9, green: 0.25, blue: 0.35, alpha: 0.9),
                                   size: CGSize(width: progressBarWidth, height: progressBarHeight))
        botFill.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        botFill.zPosition = 300
        botTrack.addChild(botFill)
        botProgressBar = botFill

        let timer = SKLabelNode(text: "01:00")
        timer.fontSize = 30
        timer.fontName = "AvenirNext-Bold"
        timer.fontColor = .yellow
        timer.zPosition = 300
        timer.horizontalAlignmentMode = .center
        uiNode.addChild(timer)
        timerLabel = timer

        let hint = SKLabelNode(text: "抢到核心，带回中心区！")
        hint.fontSize = 18
        hint.fontName = "AvenirNext-DemiBold"
        hint.fontColor = .yellow
        hint.zPosition = 300
        uiNode.addChild(hint)
        hintLabel = hint
    }

    private func layoutUI() {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        if let base = joystick {
            base.position = CGPoint(x: -halfWidth + 110, y: -halfHeight + 130)
        }
        if let knob = joystickKnob, let base = joystick {
            knob.position = base.position
        }

        let scoreY = halfHeight - 42
        let scorePos = CGPoint(x: 0, y: scoreY)
        scoreBoardBackground?.position = scorePos
        scoreBoardShadow?.position = CGPoint(x: scorePos.x, y: scorePos.y - 2)
        scoreBoardLabel?.position = scorePos

        let barY = scoreY - 22
        playerProgressTrack?.position = CGPoint(x: -scoreBackgroundSize.width / 2 + progressBarWidth / 2 + 14, y: barY)
        botProgressTrack?.position = CGPoint(x: scoreBackgroundSize.width / 2 - progressBarWidth / 2 - 14, y: barY)
        playerProgressBar?.position = CGPoint(x: -progressBarWidth / 2, y: 0)
        botProgressBar?.position = CGPoint(x: progressBarWidth / 2, y: 0)

        timerLabel?.position = CGPoint(x: 0, y: scoreY - 54)
        hintLabel?.position = CGPoint(x: 0, y: scoreY - 88)
    }

    // MARK: - 触摸（更宽松：左下角区域即可启动摇杆）
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = uiNode.convert(touch.location(in: self), from: self)

        if isMatchOver {
            _ = handleMatchEndTouch(at: loc)
            return
        }

        if let base = joystick {
            let d = hypot(loc.x - base.position.x, loc.y - base.position.y)
            if d <= joystickTouchRadius || (loc.x < 0 && loc.y < 0) {
                isTouching = true
                updateJoystick(with: loc)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isMatchOver, isTouching, let touch = touches.first else { return }
        let loc = uiNode.convert(touch.location(in: self), from: self)
        updateJoystick(with: loc)
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
        updateCameraFollow()
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
        let center = worldCenter
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
        focusCameraInstantly()

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
            showMatchEndOverlay()
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
            let center = worldCenter
            let offset = min(worldSize.width, worldSize.height) * 0.28
            c.position = CGPoint(x: center.x, y: center.y + offset)
            if c.parent == nil { worldNode.addChild(c) }
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
        let text = "玩家 \(playerScore) : \(botScore) Bot"
        scoreBoardLabel?.text = text
        scoreBoardShadow?.text = text

        let playerRatio = CGFloat(playerScore) / CGFloat(max(targetScore, 1))
        let botRatio = CGFloat(botScore) / CGFloat(max(targetScore, 1))
        playerProgressBar?.xScale = max(0.0, min(1.0, playerRatio))
        botProgressBar?.xScale = max(0.0, min(1.0, botRatio))

        animateScoreBoardChange()
    }

    private func updateTimerLabel() {
        let minutes = Int(roundTimeRemaining) / 60
        let seconds = Int(roundTimeRemaining) % 60
        timerLabel?.text = String(format: "%02d:%02d", minutes, seconds)
    }

    private func animateScoreBoardChange() {
        let pulse = SKAction.sequence([
            .scale(to: 1.12, duration: 0.08),
            .scale(to: 1.0, duration: 0.14)
        ])

        if let label = scoreBoardLabel {
            label.removeAction(forKey: "scorePulse")
            label.run(pulse, withKey: "scorePulse")
        }

        if let shadow = scoreBoardShadow, let copy = pulse.copy() as? SKAction {
            shadow.removeAction(forKey: "scorePulse")
            shadow.run(copy, withKey: "scorePulse")
        }

        if let bg = scoreBoardBackground {
            bg.removeAction(forKey: "scoreFlash")
            let originalColor = bg.fillColor
            let flash = SKAction.sequence([
                .run { bg.fillColor = UIColor(red: 0.18, green: 0.4, blue: 0.7, alpha: 0.92) },
                .wait(forDuration: 0.16),
                .run { bg.fillColor = originalColor }
            ])
            bg.run(flash, withKey: "scoreFlash")
        }
    }

    private func showMatchEndOverlay() {
        matchEndOverlay?.removeFromParent()

        let overlay = SKNode()
        overlay.zPosition = 1200
        overlay.name = "matchEndOverlay"
        overlay.alpha = 0.0

        let panel = SKShapeNode(rectOf: CGSize(width: size.width * 0.78, height: 190), cornerRadius: 18)
        panel.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.86)
        panel.strokeColor = UIColor.white.withAlphaComponent(0.9)
        panel.lineWidth = 3
        panel.zPosition = 0
        overlay.addChild(panel)

        let title = SKLabelNode(text: "比赛结束")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 34
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 42)
        title.zPosition = 1
        overlay.addChild(title)

        let subtitle = SKLabelNode(text: "再来一局？")
        subtitle.fontName = "AvenirNext-DemiBold"
        subtitle.fontSize = 22
        subtitle.fontColor = UIColor.white.withAlphaComponent(0.85)
        subtitle.position = CGPoint(x: 0, y: 12)
        subtitle.zPosition = 1
        overlay.addChild(subtitle)

        let button = SKShapeNode(rectOf: CGSize(width: 220, height: 66), cornerRadius: 14)
        button.name = "restartButton"
        button.fillColor = UIColor(red: 0.2, green: 0.8, blue: 0.45, alpha: 0.95)
        button.strokeColor = UIColor.white
        button.lineWidth = 2
        button.position = CGPoint(x: 0, y: -44)
        button.zPosition = 1
        overlay.addChild(button)

        let buttonLabel = SKLabelNode(text: "再来一局")
        buttonLabel.fontName = "AvenirNext-Bold"
        buttonLabel.fontSize = 26
        buttonLabel.fontColor = .white
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.zPosition = 2
        button.addChild(buttonLabel)

        overlay.position = CGPoint(x: 0, y: 0)
        overlay.setScale(0.88)
        uiNode.addChild(overlay)
        matchEndOverlay = overlay

        overlay.run(.group([
            .fadeIn(withDuration: 0.2),
            .scale(to: 1.0, duration: 0.2)
        ]))
    }

    private func resetMatch() {
        isMatchOver = false
        isRoundActive = false
        playerScore = 0
        botScore = 0
        roundIndex = 0
        roundTimeRemaining = roundDuration
        matchEndOverlay?.removeFromParent()
        matchEndOverlay = nil
        updateScoreBoard()
        updateTimerLabel()
        startRound()
    }

    @discardableResult
    private func handleMatchEndTouch(at point: CGPoint) -> Bool {
        let nodesHit = uiNode.nodes(at: point)
        for node in nodesHit {
            if node.name == "restartButton" || node.parent?.name == "restartButton" {
                matchEndOverlay?.run(.sequence([
                    .scale(to: 1.04, duration: 0.08),
                    .scale(to: 1.0, duration: 0.08)
                ]))
                resetMatch()
                return true
            }
        }
        return false
    }

    private func showMessage(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontSize = 22
        label.fontColor = color
        label.position = CGPoint(x: 0, y: size.height / 2 - 135)
        label.zPosition = 400
        uiNode.addChild(label)

        label.run(.sequence([
            .fadeIn(withDuration: 0.05),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
    }

    private func clampCameraPosition(_ position: CGPoint) -> CGPoint {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        let minX = halfWidth
        let maxX = max(halfWidth, worldSize.width - halfWidth)
        let minY = halfHeight
        let maxY = max(halfHeight, worldSize.height - halfHeight)

        let clampedX = min(max(position.x, minX), maxX)
        let clampedY = min(max(position.y, minY), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func focusCameraInstantly() {
        if let me = players.first {
            cameraNode.position = clampCameraPosition(me.position)
        } else {
            cameraNode.position = clampCameraPosition(worldCenter)
        }
    }

    private func updateCameraFollow() {
        guard let me = players.first else { return }
        let target = me.position
        let desired = CGPoint(
            x: cameraNode.position.x + (target.x - cameraNode.position.x) * cameraLerp,
            y: cameraNode.position.y + (target.y - cameraNode.position.y) * cameraLerp
        )
        cameraNode.position = clampCameraPosition(desired)
    }
}
