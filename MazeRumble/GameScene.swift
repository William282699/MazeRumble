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

    // MARK: - 游戏对象
    private var players: [Player] = []               // 8个玩家（0号是你）
    private var spawnPositions: [CGPoint] = []       // 出生点
    private var core: SKShapeNode?                   // 核心物品
    private var coreHolder: Player?                  // 谁拿着核心
    private var coreHitCount = 0
    private var coreArrow: SKShapeNode?

    // 道具与计时
    private var playerItems: [[String]] = Array(repeating: [], count: 8)
    private var lastItemGiveTime: TimeInterval = 0

    // 终点门
    private var gates: [SKShapeNode] = []

    // 破门冲刺
    private var finalDashTriggered = false
    private var finalDashEndTime: TimeInterval = 0
    private var finalDashUsed = false

    private var roundTimeRemaining: TimeInterval = GameConfig.gameTimeLimit
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - 游戏状态
    private var isMatchOver = false

    // MARK: - 世界 / 相机
    private var worldSize: CGSize = .zero
    private let worldNode = SKNode()
    private let uiNode = SKNode()
    private let cameraNode = SKCameraNode()
    private var inputController: InputController?
    private var uiManager: UIManager?

    // MARK: - 初始化场景
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero

        worldSize = CGSize(width: size.width * GameConfig.worldScaleFactor,
                           height: size.height * GameConfig.worldScaleFactor)

        addChild(worldNode)
        addChild(cameraNode)
        cameraNode.addChild(uiNode)
        camera = cameraNode
        uiNode.zPosition = 10_000

        inputController = InputController(uiNode: uiNode)
        uiManager = UIManager(uiNode: uiNode)

        createBorder()
        createMaze()
        createCenterZone()
        createGates()
        createCore()
        createPlayers()
        inputController?.createJoystick()
        uiManager?.createUI()
        inputController?.layoutJoystick(for: size)
        uiManager?.layoutUI(for: size)
        focusCameraInstantly()
        startRound()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        inputController?.layoutJoystick(for: size)
        uiManager?.layoutUI(for: size)
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

    // MARK: - 终点门
    private func createGates() {
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

            let player = Player(index: i, color: colors[i], isMainPlayer: i == 0)
            player.position = spawn

            worldNode.addChild(player)
            players.append(player)
        }
    }

    // MARK: - 虚拟摇杆
    // MARK: - 触摸（更宽松：左下角区域即可启动摇杆）
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isMatchOver else { return }
        guard let touch = touches.first else { return }
        let loc = uiNode.convert(touch.location(in: self), from: self)
        inputController?.handleTouchBegan(at: loc)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isMatchOver, let touch = touches.first else { return }
        let loc = uiNode.convert(touch.location(in: self), from: self)
        inputController?.handleTouchMoved(at: loc)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputController?.handleTouchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputController?.handleTouchEnded()
    }

    // MARK: - 每帧更新
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard !isMatchOver else { return }

        updateTimer(delta: dt)
        updatePlayerMovement()
        updateBotAI()
        checkCorePickup()
        checkFinishGates()
        checkFinalDash(currentTime: currentTime)
        updateCoreAutoItems(currentTime: currentTime)
        updateUI()
        updateCameraFollow()
    }

    private func updateTimer(delta: TimeInterval) {
        guard !isMatchOver else { return }
        roundTimeRemaining = max(0, roundTimeRemaining - delta)
        if roundTimeRemaining <= 0 {
            handleTimeUp()
        }
    }

    private func updateUI() {
        uiManager?.updateUI(coreHolder: coreHolder,
                            players: players,
                            coreHitCount: coreHitCount,
                            roundTimeRemaining: roundTimeRemaining)
    }

    // MARK: - 你（0号玩家）移动：目标速度插值
    private func updatePlayerMovement() {
        guard let me = players.first, let body = me.physicsBody else { return }

        let speedMultiplier: CGFloat = (finalDashTriggered && coreHolder == me) ? GameConfig.finalDashSpeedMultiplier : 1.0
        let desiredSpeed = GameConfig.playerMaxSpeed * speedMultiplier

        let moveDirection = inputController?.currentDirection ?? .zero
        let desired = CGVector(dx: moveDirection.dx * desiredSpeed,
                              dy: moveDirection.dy * desiredSpeed)

        let vx = body.velocity.dx + (desired.dx - body.velocity.dx) * GameConfig.accelLerp
        let vy = body.velocity.dy + (desired.dy - body.velocity.dy) * GameConfig.accelLerp
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

            let speedMultiplier: CGFloat = (finalDashTriggered && coreHolder == bot) ? GameConfig.finalDashSpeedMultiplier : 1.0
            let desiredSpeed = GameConfig.botMaxSpeed * speedMultiplier

            let desired = CGVector(dx: dir.dx * desiredSpeed,
                                  dy: dir.dy * desiredSpeed)

            let vx = body.velocity.dx + (desired.dx - body.velocity.dx) * GameConfig.botAccelLerp
            let vy = body.velocity.dy + (desired.dy - body.velocity.dy) * GameConfig.botAccelLerp
            body.velocity = CGVector(dx: vx, dy: vy)
        }
    }

    // MARK: - 核心拾取
    private func checkCorePickup() {
        guard let c = core, coreHolder == nil else { return }

        for p in players {
            let d = hypot(p.position.x - c.position.x, p.position.y - c.position.y)
            if d < GameConfig.pickupDistance {
                pickupCore(player: p)
                break
            }
        }
    }

    private func pickupCore(player: Player) {
        coreHolder = player
        coreHitCount = 0
        finalDashTriggered = false
        finalDashEndTime = 0
        finalDashUsed = false
        lastItemGiveTime = 0

        player.setScale(1.0)
        player.childNode(withName: "glow")?.removeFromParent()

        core?.isHidden = true
        attachCoreArrow(to: player)

        let holderIndex = players.firstIndex(of: player) ?? 0
        let text = (holderIndex == 0) ? "你拿到核心！" : "Bot\(holderIndex)拿到核心！"
        showMessage(text, color: (holderIndex == 0) ? .green : .red)
    }

    private func dropCore(from player: Player) {
        guard let c = core else { return }

        coreHolder = nil
        coreHitCount = 0
        finalDashTriggered = false
        finalDashEndTime = 0
        finalDashUsed = false

        player.setScale(1.0)
        player.childNode(withName: "glow")?.removeFromParent()
        removeCoreArrow()
        removeFinalDashEffect(from: player)

        let angle = CGFloat.random(in: 0...(2 * .pi))
        c.position = CGPoint(x: player.position.x + cos(angle) * GameConfig.dropDistance,
                            y: player.position.y + sin(angle) * GameConfig.dropDistance)
        c.isHidden = false

        showMessage("核心掉落！", color: .orange)
    }

    private func attachCoreArrow(to holder: Player) {
        removeCoreArrow()
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: -22, y: 60))
        arrowPath.addLine(to: CGPoint(x: 22, y: 60))
        arrowPath.addLine(to: CGPoint(x: 0, y: 110))
        arrowPath.closeSubpath()

        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .red
        arrow.strokeColor = .white
        arrow.lineWidth = 3
        arrow.zPosition = 500
        arrow.name = "coreArrow"

        holder.addChild(arrow)
        coreArrow = arrow
    }

    private func removeCoreArrow() {
        coreArrow?.removeFromParent()
        coreArrow = nil
    }

    private func addFinalDashEffect(to holder: Player) {
        removeFinalDashEffect(from: holder)
        let glow = SKShapeNode(circleOfRadius: 34)
        glow.strokeColor = .yellow
        glow.lineWidth = 4
        glow.glowWidth = 12
        glow.fillColor = .clear
        glow.name = "finalDashGlow"
        glow.zPosition = 400

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ])
        glow.run(.repeatForever(pulse))
        holder.addChild(glow)
    }

    private func removeFinalDashEffect(from holder: Player) {
        holder.childNode(withName: "finalDashGlow")?.removeFromParent()
    }

    // MARK: - 终点门胜利
    private func checkFinishGates() {
        guard let holder = coreHolder else { return }
        for gate in gates {
            let d = hypot(holder.position.x - gate.position.x, holder.position.y - gate.position.y)
            if d < GameConfig.gateWinDistance {
                gameOver(winner: holder)
                break
            }
        }
    }

    // MARK: - 破门冲刺
    private func checkFinalDash(currentTime: TimeInterval) {
        guard let holder = coreHolder else { return }

        if finalDashTriggered {
            if currentTime >= finalDashEndTime {
                finalDashTriggered = false
                finalDashEndTime = 0
                removeFinalDashEffect(from: holder)
            }
            return
        }

        if finalDashUsed { return }

        for gate in gates {
            let d = hypot(holder.position.x - gate.position.x, holder.position.y - gate.position.y)
            if d < GameConfig.finalDashTriggerDistance {
                finalDashTriggered = true
                finalDashUsed = true
                finalDashEndTime = currentTime + GameConfig.finalDashDuration
                addFinalDashEffect(to: holder)
                if holder == players.first {
                    showMessage("破门冲刺！", color: .yellow)
                }
                break
            }
        }
    }

    // MARK: - 核心自动道具
    private func updateCoreAutoItems(currentTime: TimeInterval) {
        guard let holder = coreHolder else { return }
        let holderIndex = players.firstIndex(of: holder) ?? 0
        if playerItems[holderIndex].count >= GameConfig.maxItemsPerPlayer { return }

        if lastItemGiveTime == 0 {
            lastItemGiveTime = currentTime
            return
        }

        if currentTime - lastItemGiveTime >= GameConfig.itemInterval {
            lastItemGiveTime = currentTime
            let items = ["banana", "bomb", "dash"]
            if let randomItem = items.randomElement() {
                playerItems[holderIndex].append(randomItem)
                if holderIndex == 0 {
                    showMessage("核心奖励：\(randomItem)", color: .yellow)
                }
            }
        }
    }

    // MARK: - 时间到
    private func handleTimeUp() {
        guard !isMatchOver else { return }
        if let holder = coreHolder {
            gameOver(winner: holder)
        } else {
            showMessage("时间到！无人获胜", color: .yellow)
            run(.sequence([
                .wait(forDuration: 3.0),
                .run { [weak self] in self?.restartGame() }
            ]))
            isMatchOver = true
        }
    }

    // MARK: - 结束与重启
    private func gameOver(winner: Player) {
        guard !isMatchOver else { return }
        isMatchOver = true

        let idx = players.firstIndex(of: winner) ?? -1
        let text: String
        let color: UIColor
        if idx == 0 {
            text = "🎉 你赢了！"
            color = .green
        } else {
            text = "😭 Bot\(idx)赢了"
            color = .red
        }

        let label = SKLabelNode(text: text)
        label.fontSize = 60
        label.fontColor = color
        label.position = cameraNode.position
        label.zPosition = 1000
        uiNode.addChild(label)

        label.setScale(0.2)
        label.run(.sequence([
            .scale(to: 1.0, duration: 0.3),
            .wait(forDuration: 2.7),
            .removeFromParent()
        ]))

        run(.sequence([
            .wait(forDuration: 3.0),
            .run { [weak self] in self?.restartGame() }
        ]))
    }

    private func restartGame() {
        startRound()
    }

    // MARK: - 碰撞：只允许“玩家撞玩家”导致掉核
    func didBegin(_ contact: SKPhysicsContact) {
        guard let holder = coreHolder else { return }

        guard let nodeA = contact.bodyA.node as? Player,
              let nodeB = contact.bodyB.node as? Player else { return }

        let holderHit = (nodeA == holder || nodeB == holder)
        guard holderHit else { return }

        guard !finalDashTriggered else { return } // 冲刺期间无敌

        if contact.collisionImpulse > GameConfig.dropImpulseThreshold {
            coreHitCount += 1
            let displayCount = min(coreHitCount, GameConfig.dropHitsRequired)
            showMessage("核心被打中！(\(displayCount)/\(GameConfig.dropHitsRequired))", color: .orange)
            if coreHitCount >= GameConfig.dropHitsRequired {
                dropCore(from: holder)
            }
        }
    }

    // MARK: - 匹配流程
    private func startRound() {
        isMatchOver = false
        roundTimeRemaining = GameConfig.gameTimeLimit
        lastUpdateTime = 0
        coreHitCount = 0
        coreHolder = nil
        coreArrow = nil
        finalDashTriggered = false
        finalDashEndTime = 0
        playerItems = Array(repeating: [], count: 8)
        lastItemGiveTime = 0

        resetEntitiesForRound()
        uiManager?.updateTimerLabel(roundTimeRemaining: roundTimeRemaining)
        uiManager?.updateScoreBoard(coreHolder: coreHolder, players: players, coreHitCount: coreHitCount)
        focusCameraInstantly()
    }

    private func resetEntitiesForRound() {
        coreHolder = nil
        removeCoreArrow()

        if let c = core {
            c.removeAllActions()
            let center = worldCenter
            let offset = min(worldSize.width, worldSize.height) * 0.28
            c.position = CGPoint(x: center.x, y: center.y + offset)
            if c.parent == nil { worldNode.addChild(c) }
            c.zPosition = 20
            c.zRotation = .pi / 4
            c.isHidden = false
            c.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 2.0)))
        }

        for (idx, p) in players.enumerated() {
            if idx < spawnPositions.count { p.position = spawnPositions[idx] }
            p.setScale(1.0)
            p.childNode(withName: "glow")?.removeFromParent()
            p.childNode(withName: "finalDashGlow")?.removeFromParent()
            if let body = p.physicsBody {
                body.velocity = .zero
                body.angularVelocity = 0
            }
        }
    }

    // MARK: - UI helpers
    private func showMessage(_ text: String, color: UIColor) {
        uiManager?.showMessage(text, color: color, sceneSize: size)
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
            x: cameraNode.position.x + (target.x - cameraNode.position.x) * GameConfig.cameraLerp,
            y: cameraNode.position.y + (target.y - cameraNode.position.y) * GameConfig.cameraLerp
        )
        cameraNode.position = clampCameraPosition(desired)
    }
}
