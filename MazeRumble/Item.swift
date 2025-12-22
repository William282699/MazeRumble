import SpriteKit

class Item: SKNode {
    enum ItemType: String, CaseIterable {
        case stick = "棒"      // 棒子
        case bomb = "弹"       // 炸弹
        case hook = "钩"       // 钩索
        case gun = "枪"        // 枪
        case shield = "盾"     // 盾牌
    }
    
    let itemType: ItemType
    private let background: SKShapeNode
    private let label: SKLabelNode
    
    // 是否在地上（可被拾取）
    var isOnGround: Bool = true
    
    init(type: ItemType) {
        self.itemType = type
        
        // 道具外观（地上的样子）
        background = SKShapeNode(circleOfRadius: 18)
        background.fillColor = Item.color(for: type)
        background.strokeColor = .white
        background.lineWidth = 2
        background.zPosition = 15
        
        label = SKLabelNode(text: type.rawValue)
        label.fontSize = 16
        label.fontName = "AvenirNext-Bold"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 16
        
        super.init()
        
        addChild(background)
        addChild(label)
        name = "item_\(type.rawValue)"
        
        // 添加浮动动画
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.8),
            SKAction.moveBy(x: 0, y: -5, duration: 0.8)
        ])
        run(SKAction.repeatForever(float))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func color(for type: ItemType) -> SKColor {
        switch type {
        case .stick: return .brown
        case .bomb: return .red
        case .hook: return .gray
        case .gun: return .darkGray
        case .shield: return .blue
        }
    }
}
