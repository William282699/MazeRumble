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
    private var items: [Item] = []
    private var spawnPositions: [CGPoint] = []       // 出生点
    private var core: SKShapeNode?                   // 核心物品
    private var coreHolder: Player?                  // 谁拿着核心
    private var coreHitCount = 0
    private var coreArrow: SKShapeNode?

    // 道具与计时
    private var playerItems: [[String]] = Array(repeating: [], count: 8)
    private var lastItemGiveTime: TimeInterval = 0

    // 破门冲刺
    private var finalDashTriggered = false
    private var finalDashEndTime: TimeInterval = 0
    private var finalDashUsed = false

    private var roundTimeRemaining: TimeInterval = GameConfig.gameTimeLimit
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - 游戏状态
    private var isMatchOver = false
    private var isActionButtonTouch = false

    // MARK: - 世界 / 相机
    private var worldSize: CGSize = .zero
    private let worldNode = SKNode()
    private let uiNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let botAI = BotAI()
    private var mapManager: MapManager?
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

        mapManager = MapManager(scene: self, worldNode: worldNode, worldSize: worldSize)
        mapManager?.createBorder()
        mapManager?.createMaze()
        mapManager?.createCenterZone()
        mapManager?.createGates()
        createCore()
        createPlayers()
        inputController?.createJoystick()
        inputController?.createActionButtons()
        uiManager?.createUI()
        inputController?.layoutJoystick(for: size)
        uiManager?.layoutUI(for: size)
        inputController?.layoutActionButtons(for: size)
        focusCameraInstantly()
        startRound()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        inputController?.layoutJoystick(for: size)
        inputController?.layoutActionButtons(for: size)
        uiManager?.layoutUI(for: size)
    }

    private var worldCenter: CGPoint {
        CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
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

            let appearance: Player.AppearanceType = (i == 0) ? .normal : Player.AppearanceType.allCases.randomElement() ?? .normal
            let player = Player(index: i, color: colors[i], isMainPlayer: i == 0, appearance: appearance)
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

        // 先检测道具槽点击
        if let slotIndex = uiManager?.getItemSlotPressed(at: loc) {
            useItemFromSlot(slotIndex)
            isActionButtonTouch = true  // 标记这是按钮点击
            return
        }

        // 再检测动作按钮
        if let actionType = inputController?.getActionButtonPressed(at: loc) {
            isActionButtonTouch = true  // 标记这是按钮点击
            performAction(actionType)
            return
        }

        // 否则处理摇杆
        isActionButtonTouch = false
        inputController?.handleTouchBegan(at: loc)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isMatchOver, let touch = touches.first else { return }
        let loc = uiNode.convert(touch.location(in: self), from: self)
        inputController?.handleTouchMoved(at: loc)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 如果是按钮点击，不重置摇杆
        if isActionButtonTouch {
            isActionButtonTouch = false
            return
        }
        inputController?.handleTouchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isActionButtonTouch {
            isActionButtonTouch = false
            return
        }
        inputController?.handleTouchEnded()
    }

    private func performAction(_ actionType: ActionButton.ActionType) {
        guard let me = players.first, me.canAct else { return }

        switch actionType {
        case .push:
            performPush(by: me)
        case .tackle:
            performTackle(by: me)
        case .dash:
            performDash(by: me)
        case .sprint:
            performSprint(by: me)
        }
    }

    private func performPush(by player: Player) {
        // 获取推的方向（摇杆方向，如果没有则用上一次移动方向或默认向前）
        var pushDirection = inputController?.currentDirection ?? .zero
        if pushDirection.dx == 0 && pushDirection.dy == 0 {
            pushDirection = CGVector(dx: 0, dy: 1) // 默认向上
        }

        // 标准化方向
        let length = hypot(pushDirection.dx, pushDirection.dy)
        let normalizedDir = CGVector(dx: pushDirection.dx / length, dy: pushDirection.dy / length)

        var didPush = false
        // 找到范围内的其他玩家
        for target in players where target != player {
            let dx = target.position.x - player.position.x
            let dy = target.position.y - player.position.y
            let distance = hypot(dx, dy)

            if distance < GameConfig.pushRange {
                // 推开目标
                let pushVector = CGVector(dx: normalizedDir.dx * GameConfig.pushForce,
                                          dy: normalizedDir.dy * GameConfig.pushForce)
                target.physicsBody?.applyImpulse(pushVector)
                didPush = true
            }
        }

        if didPush {
            showMessage("推！", color: .cyan)
        }
    }

    private func performTackle(by player: Player) {
        // 获取铲的方向
        var tackleDirection = inputController?.currentDirection ?? .zero
        if tackleDirection.dx == 0 && tackleDirection.dy == 0 {
            tackleDirection = CGVector(dx: 0, dy: 1)
        }

        let length = hypot(tackleDirection.dx, tackleDirection.dy)
        let normalizedDir = CGVector(dx: tackleDirection.dx / length, dy: tackleDirection.dy / length)

        // 自己先冲出去一段距离
        let selfDash = CGVector(dx: normalizedDir.dx * GameConfig.tackleForce * 0.8,
                                dy: normalizedDir.dy * GameConfig.tackleForce * 0.8)
        player.physicsBody?.applyImpulse(selfDash)

        // 检测范围内的敌人并绊倒
        for target in players where target != player {
            let dx = target.position.x - player.position.x
            let dy = target.position.y - player.position.y
            let distance = hypot(dx, dy)

            if distance < GameConfig.tackleRange {
                // 绊倒目标（进入倒地状态）
                target.setState(.downed, duration: GameConfig.tackleDownDuration)

                // 也给目标一个小推力
                let pushVector = CGVector(dx: normalizedDir.dx * GameConfig.tackleForce * 0.3,
                                          dy: normalizedDir.dy * GameConfig.tackleForce * 0.3)
                target.physicsBody?.applyImpulse(pushVector)

                showMessage("铲倒！", color: .orange)
            }
        }

        // 启动冷却
        inputController?.tackleButton?.startCooldown(duration: GameConfig.tackleCooldown)
    }

    private func performDash(by player: Player) {
        var dashDirection = inputController?.currentDirection ?? .zero
        if dashDirection.dx == 0 && dashDirection.dy == 0 {
            dashDirection = CGVector(dx: 0, dy: 1)
        }

        let length = hypot(dashDirection.dx, dashDirection.dy)
        let normalizedDir = CGVector(dx: dashDirection.dx / length, dy: dashDirection.dy / length)

        // 自己冲出去
        let dashVector = CGVector(dx: normalizedDir.dx * GameConfig.dashForce,
                                 dy: normalizedDir.dy * GameConfig.dashForce)
        player.physicsBody?.applyImpulse(dashVector)

        // 冲撞范围内的敌人
        for target in players where target != player {
            let dx = target.position.x - player.position.x
            let dy = target.position.y - player.position.y
            let distance = hypot(dx, dy)

            if distance < GameConfig.dashKnockbackRange {
                let knockback = CGVector(dx: normalizedDir.dx * GameConfig.dashKnockbackForce,
                                         dy: normalizedDir.dy * GameConfig.dashKnockbackForce)
                target.physicsBody?.applyImpulse(knockback)
                showMessage("撞飞！", color: .red)
            }
        }

        inputController?.dashButton?.startCooldown(duration: GameConfig.dashCooldown)
        showMessage("猛冲！", color: .yellow)
    }

    private func performSprint(by player: Player) {
        guard !player.isSprinting else { return }  // 已经在快跑则不重复触发

        player.startSprint(duration: GameConfig.sprintDuration)
        inputController?.sprintButton?.startCooldown(duration: GameConfig.sprintCooldown)
        showMessage("快跑！", color: .green)
    }

    // MARK: - 每帧更新
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard !isMatchOver else { return }

        updateTimer(delta: dt)
        inputController?.updateActionButtons(deltaTime: dt)
        // 更新所有玩家状态
        for player in players {
            player.updateState(deltaTime: dt)
            player.updateSprint(deltaTime: dt)
        }
        updatePlayerMovement()
        if let c = core {
            botAI.coreHolder = coreHolder
            botAI.isFinalDashTriggered = finalDashTriggered
            botAI.update(bots: Array(players.dropFirst()), target: c.position)
        }
        checkCorePickup()
        checkItemPickup()
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
        if let me = players.first {
            uiManager?.updateInventoryUI(inventory: me.inventory)
        }
    }

    // MARK: - 你（0号玩家）移动：目标速度插值
    private func updatePlayerMovement() {
        guard let me = players.first, let body = me.physicsBody else { return }
        guard me.canMove else {
            body.velocity = .zero
            return
        }

        let sprintMultiplier: CGFloat = me.isSprinting ? GameConfig.sprintSpeedMultiplier : 1.0
        let speedMultiplier: CGFloat = (finalDashTriggered && coreHolder == me) ? GameConfig.finalDashSpeedMultiplier : sprintMultiplier
        let desiredSpeed = GameConfig.playerMaxSpeed * speedMultiplier

        let moveDirection = inputController?.currentDirection ?? .zero
        let desired = CGVector(dx: moveDirection.dx * desiredSpeed,
                              dy: moveDirection.dy * desiredSpeed)

        let vx = body.velocity.dx + (desired.dx - body.velocity.dx) * GameConfig.accelLerp
        let vy = body.velocity.dy + (desired.dy - body.velocity.dy) * GameConfig.accelLerp
        body.velocity = CGVector(dx: vx, dy: vy)
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

    private func checkItemPickup() {
        guard let me = players.first else { return }
        
        for item in items where item.isOnGround {
            let distance = hypot(me.position.x - item.position.x,
                                me.position.y - item.position.y)
            if distance < GameConfig.itemPickupRange {
                if me.pickupItem(item.itemType) {
                    item.removeFromParent()
                    items.removeAll { $0 === item }
                    showMessage("捡到 \(item.itemType.rawValue)！", color: .green)
                    break  // 一次只捡一个
                }
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
        for gate in mapManager?.gates ?? [] {
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

        for gate in mapManager?.gates ?? [] {
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
        if let me = players.first {
            uiManager?.updateInventoryUI(inventory: me.inventory)
        }
        focusCameraInstantly()
        spawnTestItems()
    }

    private func spawnTestItems() {
        // 清除旧道具
        items.forEach { $0.removeFromParent() }
        items.removeAll()
        
        // 在地图上随机生成几个测试道具
        let testTypes: [Item.ItemType] = [.stick, .bomb, .hook, .gun, .shield]
        let center = worldCenter
        
        for (index, type) in testTypes.enumerated() {
            let item = Item(type: type)
            let angle = CGFloat(index) * (2 * .pi / CGFloat(testTypes.count))
            let radius: CGFloat = 350
            item.position = CGPoint(x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius)
            item.zPosition = 15
            worldNode.addChild(item)
            items.append(item)
        }
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
            p.clearInventory()
            if let body = p.physicsBody {
                body.velocity = .zero
                body.angularVelocity = 0
            }
        }
    }

    // MARK: - UI helpers
    private func useItemFromSlot(_ index: Int) {
        guard let me = players.first, me.canAct else { return }
        guard let itemType = me.useItem(at: index) else { return }

        // 暂时只显示使用了什么道具
        showMessage("使用 \(itemType.rawValue)！", color: Item.color(for: itemType))

        // TODO: 后续实现具体道具效果
        switch itemType {
        case .stick:
            useStick(by: me)
        case .bomb:
            useBomb(by: me)
        case .hook:
            useHook(by: me)
        case .gun:
            useGun(by: me)
        case .shield:
            useShield(by: me)
        }

        uiManager?.updateInventoryUI(inventory: me.inventory)
    }

    private func useStick(by player: Player) {
        // 棒子：近战攻击，范围内敌人眩晕3秒
        var direction = inputController?.currentDirection ?? .zero
        if direction.dx == 0 && direction.dy == 0 {
            direction = CGVector(dx: 0, dy: 1)
        }

        for target in players where target != player {
            let dx = target.position.x - player.position.x
            let dy = target.position.y - player.position.y
            let distance = hypot(dx, dy)

            if distance < 70 {  // 棒子攻击范围
                target.setState(.stunned, duration: 3.0)
                showMessage("击晕！", color: .yellow)
            }
        }
    }

    private func useBomb(by player: Player) {
        // 获取投掷方向
        var direction = inputController?.currentDirection ?? .zero
        if direction.dx == 0 && direction.dy == 0 {
            direction = CGVector(dx: 0, dy: 1)
        }
        let length = hypot(direction.dx, direction.dy)
        let normalizedDir = CGVector(dx: direction.dx / length, dy: direction.dy / length)

        // 计算炸弹落点
        let targetX = player.position.x + normalizedDir.dx * GameConfig.bombThrowDistance
        let targetY = player.position.y + normalizedDir.dy * GameConfig.bombThrowDistance
        let targetPos = CGPoint(x: targetX, y: targetY)

        // 创建炸弹节点
        let bomb = SKShapeNode(circleOfRadius: 12)
        bomb.fillColor = .red
        bomb.strokeColor = .black
        bomb.lineWidth = 2
        bomb.position = player.position
        bomb.zPosition = 20
        bomb.name = "bomb"
        worldNode.addChild(bomb)

        // 炸弹飞行动画
        let flyAction = SKAction.move(to: targetPos, duration: 0.3)
        flyAction.timingMode = .easeOut

        // 落地后闪烁
        let blink = SKAction.sequence([
            SKAction.run { bomb.fillColor = .white },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { bomb.fillColor = .red },
            SKAction.wait(forDuration: 0.15)
        ])
        let blinkRepeat = SKAction.repeat(blink, count: Int(GameConfig.bombFuseTime / 0.3))

        // 爆炸
        let explode = SKAction.run { [weak self] in
            self?.explodeBomb(at: targetPos)
            bomb.removeFromParent()
        }

        // 组合动画
        let sequence = SKAction.sequence([flyAction, blinkRepeat, explode])
        bomb.run(sequence)
    }

    // 添加爆炸方法
    private func explodeBomb(at position: CGPoint) {
        // 爆炸视觉效果
        let explosion = SKShapeNode(circleOfRadius: 10)
        explosion.fillColor = .orange
        explosion.strokeColor = .yellow
        explosion.lineWidth = 3
        explosion.position = position
        explosion.zPosition = 25
        worldNode.addChild(explosion)

        // 爆炸扩散动画
        let expand = SKAction.scale(to: GameConfig.bombExplosionRadius / 10, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        explosion.run(SKAction.sequence([expand, fadeOut, remove]))

        // 范围内所有玩家眩晕
        for target in players {
            let dx = target.position.x - position.x
            let dy = target.position.y - position.y
            let distance = hypot(dx, dy)

            if distance < GameConfig.bombExplosionRadius {
                target.setState(.stunned, duration: GameConfig.bombStunDuration)

                // 给一个击退效果
                if distance > 0 {
                    let knockbackDir = CGVector(dx: dx / distance, dy: dy / distance)
                    let knockback = CGVector(dx: knockbackDir.dx * 300, dy: knockbackDir.dy * 300)
                    target.physicsBody?.applyImpulse(knockback)
                }
            }
        }

        showMessage("爆炸！", color: .orange)
    }

    private func useHook(by player: Player) {
        // 获取射出方向
        var direction = inputController?.currentDirection ?? .zero
        if direction.dx == 0 && direction.dy == 0 {
            direction = CGVector(dx: 0, dy: 1)
        }
        let length = hypot(direction.dx, direction.dy)
        let normalizedDir = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        
        // 计算钩索终点
        let endX = player.position.x + normalizedDir.dx * GameConfig.hookRange
        let endY = player.position.y + normalizedDir.dy * GameConfig.hookRange
        let endPos = CGPoint(x: endX, y: endY)
        
        // 创建钩子头部
        let hook = SKShapeNode(circleOfRadius: 10)
        hook.fillColor = .gray
        hook.strokeColor = .darkGray
        hook.lineWidth = 2
        hook.position = player.position
        hook.zPosition = 20
        hook.name = "hook"
        worldNode.addChild(hook)
        
        // 创建绳索（线条）
        let rope = SKShapeNode()
        rope.strokeColor = .brown
        rope.lineWidth = 3
        rope.zPosition = 19
        rope.name = "rope"
        worldNode.addChild(rope)
        
        // 记录发射者位置用于绳索绘制
        let startPos = player.position
        
        // 用于标记是否已命中
        var hasHit = false
        
        // 飞行过程中每帧检测命中 + 更新绳索
        let flyAndCheck = SKAction.customAction(withDuration: GameConfig.hookSpeed) { [weak self, weak hook, weak rope] node, elapsedTime in
            guard let self = self, let hookNode = hook, let ropeNode = rope, !hasHit else { return }
            
            // 计算当前位置（手动插值，因为 customAction 会覆盖 move）
            let progress = elapsedTime / CGFloat(GameConfig.hookSpeed)
            let easeOutProgress = 1 - pow(1 - progress, 2)  // easeOut 曲线
            let currentX = startPos.x + (endPos.x - startPos.x) * easeOutProgress
            let currentY = startPos.y + (endPos.y - startPos.y) * easeOutProgress
            hookNode.position = CGPoint(x: currentX, y: currentY)
            
            // 更新绳索
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startPos.x - hookNode.position.x, y: startPos.y - hookNode.position.y))
            path.addLine(to: .zero)
            ropeNode.path = path
            ropeNode.position = hookNode.position
            
            // 检测命中（每帧检测）
            for target in self.players where target != player {
                let dx = target.position.x - hookNode.position.x
                let dy = target.position.y - hookNode.position.y
                let distance = hypot(dx, dy)
                
                if distance < 50 {  // 命中判定范围
                    hasHit = true
                    
                    // 命中：绊倒目标并拉过来
                    target.setState(.downed, duration: GameConfig.hookDownDuration)
                    
                    // 把目标拉向玩家
                    let pullDx = player.position.x - target.position.x
                    let pullDy = player.position.y - target.position.y
                    let pullDist = hypot(pullDx, pullDy)
                    if pullDist > 0 {
                        let pullDir = CGVector(dx: pullDx / pullDist * GameConfig.hookPullForce,
                                               dy: pullDy / pullDist * GameConfig.hookPullForce)
                        target.physicsBody?.applyImpulse(pullDir)
                    }
                    
                    self.showMessage("钩中！", color: .brown)
                    
                    // 立即开始收回
                    hookNode.removeAllActions()
                    self.retractHook(hook: hookNode, rope: ropeNode, to: startPos)
                    return
                }
            }
        }
        
        // 未命中时的收回
        let retractIfMissed = SKAction.run { [weak self, weak hook, weak rope] in
            guard let self = self, let hookNode = hook, let ropeNode = rope, !hasHit else { return }
            self.retractHook(hook: hookNode, rope: ropeNode, to: startPos)
        }
        
        // 组合动作
        hook.run(SKAction.sequence([flyAndCheck, retractIfMissed]))
    }
    
    // 钩索收回辅助方法
    private func retractHook(hook: SKShapeNode, rope: SKShapeNode, to startPos: CGPoint) {
        let retractDuration = GameConfig.hookSpeed * 0.7
        
        let retractAction = SKAction.customAction(withDuration: retractDuration) { [weak rope] node, elapsedTime in
            guard let hookNode = node as? SKShapeNode, let ropeNode = rope else { return }
            
            let startRetractPos = hookNode.position
            let progress = elapsedTime / CGFloat(retractDuration)
            let easeInProgress = progress * progress  // easeIn 曲线
            
            // 这里需要记录收回开始位置，简化处理：直接移动
            let currentX = hookNode.position.x + (startPos.x - hookNode.position.x) * easeInProgress * 0.1
            let currentY = hookNode.position.y + (startPos.y - hookNode.position.y) * easeInProgress * 0.1
            hookNode.position = CGPoint(x: currentX, y: currentY)
            
            // 更新绳索
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startPos.x - hookNode.position.x, y: startPos.y - hookNode.position.y))
            path.addLine(to: .zero)
            ropeNode.path = path
            ropeNode.position = hookNode.position
        }
        
        let moveBack = SKAction.move(to: startPos, duration: retractDuration)
        moveBack.timingMode = .easeIn
        
        let remove = SKAction.run { [weak rope] in
            hook.removeFromParent()
            rope?.removeFromParent()
        }
        
        // 用 move 来收回，同时更新绳索
        let updateRopeBack = SKAction.customAction(withDuration: retractDuration) { [weak rope] node, _ in
            guard let hookNode = node as? SKShapeNode, let ropeNode = rope else { return }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startPos.x - hookNode.position.x, y: startPos.y - hookNode.position.y))
            path.addLine(to: .zero)
            ropeNode.path = path
            ropeNode.position = hookNode.position
        }
        
        hook.run(SKAction.sequence([
            SKAction.group([moveBack, updateRopeBack]),
            remove
        ]))
    }

    private func useGun(by player: Player) {
        // TODO: 枪
        showMessage("枪功能待实现", color: .darkGray)
    }

    private func useShield(by player: Player) {
        // TODO: 盾牌
        showMessage("盾牌功能待实现", color: .blue)
    }

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
