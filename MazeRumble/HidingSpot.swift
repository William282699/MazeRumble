import SpriteKit

final class HidingSpot: SKNode {
    private let background: SKShapeNode
    private let icon: SKLabelNode
    private let radius: CGFloat
    
    // 当前在里面的玩家
    private(set) var hiddenPlayers: [Player] = []
    
    init(radius: CGFloat = GameConfig.hidingSpotRadius) {
        self.radius = radius
        
        // 隐藏点外观（草丛/箱子的简化表示）
        background = SKShapeNode(circleOfRadius: radius)
        background.fillColor = SKColor.green.withAlphaComponent(0.4)
        background.strokeColor = SKColor.green.withAlphaComponent(0.6)
        background.lineWidth = 3
        background.zPosition = 5
        
        // 图标（有人时会隐藏）
        icon = SKLabelNode(text: "🌿")
        icon.fontSize = 30
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.zPosition = 6
        
        super.init()
        
        addChild(background)
        addChild(icon)
        name = "hidingSpot"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 检测玩家是否在隐藏点范围内
    func containsPlayer(_ player: Player) -> Bool {
        let dx = player.position.x - position.x
        let dy = player.position.y - position.y
        return hypot(dx, dy) < radius
    }
    
    /// 玩家进入隐藏点
    func playerEnter(_ player: Player) {
        guard !hiddenPlayers.contains(where: { $0 === player }) else { return }
        hiddenPlayers.append(player)
        updateVisuals()
    }
    
    /// 玩家离开隐藏点
    func playerExit(_ player: Player) {
        hiddenPlayers.removeAll { $0 === player }
        updateVisuals()
    }
    
    /// 更新视觉效果
    private func updateVisuals() {
        // 有人躲藏时，图标消失（让其他玩家不知道里面有人）
        if hiddenPlayers.isEmpty {
            icon.alpha = 1.0
            background.fillColor = SKColor.green.withAlphaComponent(0.4)
        } else {
            icon.alpha = 0.0  // 图标消失！
            background.fillColor = SKColor.green.withAlphaComponent(0.25)
        }
    }
    
    /// 清空所有隐藏玩家
    func reset() {
        hiddenPlayers.removeAll()
        updateVisuals()
    }
}
