//
//  GameViewController.swift
//  MazeRumble
//
//  Created by Yuqiao Huang on 2025-12-19.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - 游戏对象
    var players: [SKShapeNode] = []              // 8个玩家
    var core: SKShapeNode?                        // 核心物品
    var coreHolder: SKShapeNode?                  // 谁拿着核心
    
    // MARK: - 控制
    var joystick: SKShapeNode?                    // 摇杆底座
    var joystickKnob: SKShapeNode?                // 摇杆按钮
    var moveDirection = CGVector.zero             // 移动方向
    var isTouching = false                        // 是否正在触摸
    
    // MARK: - UI
    var scoreLabel: SKLabelNode?                  // 分数显示
    var timerLabel: SKLabelNode?                  // 计时器
    var gameTime: TimeInterval = 0                // 游戏时长
    
    // MARK: - 游戏状态
    var isGameOver = false
    
    // MARK: - 初始化场景
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        
        // 设置物理世界
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector.zero  // 无重力（俯视角）
        
        // 创建游戏元素（按顺序）
        createBorder()
        createMaze()
        createCenterZone()
        createCore()
        createPlayers()
        createJoystick()
        createUI()
    }
    
    // MARK: - 创建边界
    func createBorder() {
        let border = SKPhysicsBody(edgeLoopFrom: self.frame)
        border.friction = 0.0
        physicsBody = border
    }
    
    // MARK: - 创建迷宫
    func createMaze() {
        // 简单的墙壁布局（手工设计，快速验证）
        let wallData: [[CGFloat]] = [
            // [x, y, width, height]
            [size.width * 0.3, size.height * 0.5, 20, 200],
            [size.width * 0.5, size.height * 0.7, 250, 20],
            [size.width * 0.7, size.height * 0.4, 20, 180],
            [size.width * 0.5, size.height * 0.3, 200, 20],
            [size.width * 0.2, size.height * 0.25, 150, 20],
            [size.width * 0.8, size.height * 0.65, 120, 20],
        ]
        
        for data in wallData {
            let wall = SKShapeNode(rectOf: CGSize(width: data[2], height: data[3]))
            wall.fillColor = SKColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
            wall.strokeColor = .black
            wall.lineWidth = 2
            wall.position = CGPoint(x: data[0], y: data[1])
            
            // 静态物理体
            wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: data[2], height: data[3]))
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.friction = 0.3
            wall.physicsBody?.restitution = 0.2
            
            addChild(wall)
        }
    }
    
    // MARK: - 创建中心区域（目标区）
    func createCenterZone() {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // 半透明圆圈标记中心
        let zone = SKShapeNode(circleOfRadius: 100)
        zone.fillColor = SKColor.yellow
        zone.strokeColor = SKColor.orange
        zone.lineWidth = 4
        zone.alpha = 0.3
        zone.position = CGPoint(x: centerX, y: centerY)
        zone.name = "centerZone"
        addChild(zone)
        
        // 添加脉冲动画
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 1.0),
            SKAction.scale(to: 1.0, duration: 1.0)
        ])
        zone.run(SKAction.repeatForever(pulse))
        
        // 中心文字
        let label = SKLabelNode(text: "目标区")
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: centerX, y: centerY)
        addChild(label)
    }
    
    // MARK: - 创建核心
    func createCore() {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // 钻石形状的核心
        let core = SKShapeNode(rectOf: CGSize(width: 30, height: 30))
        core.fillColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        core.strokeColor = .white
        core.lineWidth = 3
        core.zRotation = .pi / 4  // 旋转45度
        core.position = CGPoint(x: centerX, y: centerY + 150)
        core.name = "core"
        
        // 发光效果
        core.glowWidth = 10
        
        // 旋转动画
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
        core.run(SKAction.repeatForever(rotate))
        
        addChild(core)
        self.core = core
    }
    
    // MARK: - 创建玩家
    func createPlayers() {
        let colors: [UIColor] = [
            .red, .blue, .green, .yellow,
            .orange, .purple, .cyan, .white
        ]
        
        // 8个出生点（圆形分布）
        let centerX = size.width / 2
        let centerY = size.height / 2
        let spawnRadius: CGFloat = 250
        
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4  // 每45度一个
            let x = centerX + cos(angle) * spawnRadius
            let y = centerY + sin(angle) * spawnRadius
            
            let player = SKShapeNode(circleOfRadius: 20)
            player.fillColor = colors[i]
            player.strokeColor = .black
            player.lineWidth = 2
            player.position = CGPoint(x: x, y: y)
            player.name = "player_\(i)"
            
            // 物理体
            player.physicsBody = SKPhysicsBody(circleOfRadius: 20)
            player.physicsBody?.isDynamic = true
            player.physicsBody?.mass = 1.0
            player.physicsBody?.friction = 0.2
            player.physicsBody?.restitution = 0.6
            player.physicsBody?.linearDamping = 1.5  // 阻尼，让移动不会太滑
            player.physicsBody?.allowsRotation = false  // 不旋转
            
            // 碰撞检测
            player.physicsBody?.categoryBitMask = 1
            player.physicsBody?.contactTestBitMask = 1
            player.physicsBody?.collisionBitMask = 1
            
            addChild(player)
            players.append(player)
        }
        
        // 给第一个玩家（你）加个标记
        if let firstPlayer = players.first {
            let arrow = SKShapeNode(path: createArrowPath())
            arrow.fillColor = .white
            arrow.strokeColor = .black
            arrow.lineWidth = 2
            arrow.position = CGPoint(x: 0, y: 35)
            arrow.name = "arrow"
            firstPlayer.addChild(arrow)
            
            // 箭头跳动动画
            let bounce = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 5, duration: 0.5),
                SKAction.moveBy(x: 0, y: -5, duration: 0.5)
            ])
            arrow.run(SKAction.repeatForever(bounce))
        }
    }
    
    // 创建箭头路径
    func createArrowPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 10))
        path.addLine(to: CGPoint(x: -8, y: 0))
        path.addLine(to: CGPoint(x: 8, y: 0))
        path.closeSubpath()
        return path
    }
    
    // MARK: - 创建虚拟摇杆
    func createJoystick() {
        let baseRadius: CGFloat = 70
        let knobRadius: CGFloat = 35
        
        // 底座
        let base = SKShapeNode(circleOfRadius: baseRadius)
        base.fillColor = SKColor.gray.withAlphaComponent(0.4)
        base.strokeColor = .white
        base.lineWidth = 2
        base.position = CGPoint(x: 100, y: 120)
        base.zPosition = 100
        addChild(base)
        joystick = base
        
        // 按钮
        let knob = SKShapeNode(circleOfRadius: knobRadius)
        knob.fillColor = SKColor.white.withAlphaComponent(0.7)
        knob.strokeColor = .black
        knob.lineWidth = 2
        knob.position = base.position
        knob.zPosition = 101
        addChild(knob)
        joystickKnob = knob
    }
    
    // MARK: - 创建UI
    func createUI() {
        // 计时器
        let timer = SKLabelNode(text: "00:00")
        timer.fontSize = 32
        timer.fontColor = .white
        timer.position = CGPoint(x: size.width / 2, y: size.height - 50)
        timer.zPosition = 100
        addChild(timer)
        timerLabel = timer
        
        // 状态提示
        let hint = SKLabelNode(text: "抢到核心，带回中心区！")
        hint.fontSize = 20
        hint.fontColor = .yellow
        hint.position = CGPoint(x: size.width / 2, y: size.height - 90)
        hint.zPosition = 100
        addChild(hint)
        
        // 淡入淡出动画
        let fade = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.0),
            SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        ])
        hint.run(SKAction.repeatForever(fade))
    }
    
    // MARK: - 触摸处理
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 检查是否点击了摇杆区域
        if let joystick = joystick {
            let distance = hypot(location.x - joystick.position.x,
                               location.y - joystick.position.y)
            if distance < 150 {
                isTouching = true
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTouching,
              let touch = touches.first,
              let joystick = joystick,
              let knob = joystickKnob else { return }
        
        let location = touch.location(in: self)
        
        let dx = location.x - joystick.position.x
        let dy = location.y - joystick.position.y
        let distance = hypot(dx, dy)
        
        let maxDistance: CGFloat = 70
        
        if distance < maxDistance {
            knob.position = location
        } else {
            let angle = atan2(dy, dx)
            knob.position = CGPoint(
                x: joystick.position.x + cos(angle) * maxDistance,
                y: joystick.position.y + sin(angle) * maxDistance
            )
        }
        
        // 计算移动方向（归一化）
        if distance > 5 {
            moveDirection = CGVector(dx: dx / distance, dy: dy / distance)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        joystickKnob?.position = joystick?.position ?? .zero
        moveDirection = .zero
    }
    
    // MARK: - 每帧更新
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
        // 更新计时器
        gameTime += 1.0 / 60.0
        let minutes = Int(gameTime) / 60
        let seconds = Int(gameTime) % 60
        timerLabel?.text = String(format: "%02d:%02d", minutes, seconds)
        
        // 更新玩家移动
        updatePlayerMovement()
        
        // 更新Bot AI
        updateBotAI()
        
        // 检查核心拾取
        checkCorePickup()
        
        // 检查胜利条件
        checkWinCondition()
    }
    
    // MARK: - 玩家移动
    func updatePlayerMovement() {
        guard let player = players.first,
              let body = player.physicsBody else { return }
        
        let speed: CGFloat = 300  // 移动速度
        let force = CGVector(
            dx: moveDirection.dx * speed,
            dy: moveDirection.dy * speed
        )
        
        body.applyForce(force)
        
        // 限制最大速度
        let maxSpeed: CGFloat = 200
        let velocity = body.velocity
        let currentSpeed = hypot(velocity.dx, velocity.dy)
        
        if currentSpeed > maxSpeed {
            let scale = maxSpeed / currentSpeed
            body.velocity = CGVector(
                dx: velocity.dx * scale,
                dy: velocity.dy * scale
            )
        }
    }
    
    // MARK: - Bot AI
    func updateBotAI() {
        guard let core = core else { return }
        
        for i in 1..<players.count {
            let bot = players[i]
            guard let body = bot.physicsBody else { continue }
            
            // 决定目标：核心或持有者
            let target: CGPoint
            if let holder = coreHolder, holder != bot {
                target = holder.position
            } else {
                target = core.position
            }
            
            // 计算方向
            let dx = target.x - bot.position.x
            let dy = target.y - bot.position.y
            let distance = hypot(dx, dy)
            
            if distance > 30 {
                let botSpeed: CGFloat = 200  // Bot速度略慢
                let force = CGVector(
                    dx: (dx / distance) * botSpeed,
                    dy: (dy / distance) * botSpeed
                )
                body.applyForce(force)
            }
        }
    }
    
    // MARK: - 核心拾取检测
    func checkCorePickup() {
        guard let core = core, coreHolder == nil else { return }
        
        for player in players {
            let distance = hypot(
                player.position.x - core.position.x,
                player.position.y - core.position.y
            )
            
            if distance < 40 {
                pickupCore(player: player)
                break
            }
        }
    }
    
    func pickupCore(player: SKShapeNode) {
        coreHolder = player
        player.setScale(1.4)  // 变大
        
        // 视觉反馈
        let glow = SKShapeNode(circleOfRadius: 35)
        glow.strokeColor = .yellow
        glow.lineWidth = 3
        glow.glowWidth = 10
        glow.name = "glow"
        player.addChild(glow)
        
        // 提示文字
        let isPlayer1 = player == players.first
        let text = isPlayer1 ? "你拿到了核心！" : "Bot拿到了核心！"
        showMessage(text, color: isPlayer1 ? .green : .red)
        
        // 音效（如果有）
        // run(SKAction.playSoundFileNamed("pickup.wav", waitForCompletion: false))
    }
    
    func dropCore(from player: SKShapeNode) {
        guard let core = core else { return }
        
        coreHolder = nil
        player.setScale(1.0)
        player.childNode(withName: "glow")?.removeFromParent()
        
        // 核心飞出
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance: CGFloat = 80
        core.position = CGPoint(
            x: player.position.x + cos(angle) * distance,
            y: player.position.y + sin(angle) * distance
        )
        
        showMessage("核心掉落！", color: .orange)
    }
    
    // MARK: - 胜利条件检测
    func checkWinCondition() {
        guard let holder = coreHolder else { return }
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        let distance = hypot(
            holder.position.x - centerX,
            holder.position.y - centerY
        )
        
        if distance < 100 {
            // 进入中心区，开始读条
            // 简化版：直接判定胜利
            gameOver(winner: holder)
        }
    }
    
    func gameOver(winner: SKShapeNode) {
        isGameOver = true
        
        let isPlayer1 = winner == players.first
        let text = isPlayer1 ? "🎉 你赢了！" : "😭 Bot赢了"
        
        let label = SKLabelNode(text: text)
        label.fontSize = 60
        label.fontColor = isPlayer1 ? .green : .red
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 200
        addChild(label)
        
        // 放大动画
        label.setScale(0)
        label.run(SKAction.scale(to: 1.0, duration: 0.5))
        
        // 3秒后重启
        run(SKAction.sequence([
            SKAction.wait(forDuration: 3),
            SKAction.run { [weak self] in
                self?.restartGame()
            }
        ]))
    }
    
    func restartGame() {
        // 简单重启：重新加载场景
        if let view = self.view {
            let newScene = GameScene(size: self.size)
            newScene.scaleMode = .aspectFill
            view.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.5))
        }
    }
    
    // MARK: - 碰撞处理
    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA.node
        let bodyB = contact.bodyB.node
        
        // 检查是否撞到了持有核心的人
        if let holder = coreHolder {
            if bodyA == holder || bodyB == holder {
                let impulse = contact.collisionImpulse
                
                // 撞击力度够大，核心掉落
                if impulse > 50 {
                    dropCore(from: holder)
                    
                    // 屏幕震动
                    let shake = SKAction.sequence([
                        SKAction.moveBy(x: 5, y: 5, duration: 0.05),
                        SKAction.moveBy(x: -10, y: -10, duration: 0.05),
                        SKAction.moveBy(x: 5, y: 5, duration: 0.05)
                    ])
                    camera?.run(shake)
                }
            }
        }
    }
    
    // MARK: - 辅助函数
    func showMessage(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontSize = 28
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: size.height - 130)
        label.zPosition = 100
        addChild(label)
        
        // 淡出消失
        label.run(SKAction.sequence([
            SKAction.wait(forDuration: 2),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
}
