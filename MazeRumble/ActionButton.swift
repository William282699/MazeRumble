//
//  ActionButton.swift
//  MazeRumble
//
//  Created by ChatGPT on 2025-XX-XX.
//

import SpriteKit

final class ActionButton: SKNode {
    enum ActionType: String {
        case push = "推"
        case tackle = "铲"
        case dash = "冲"
        case sprint = "跑"
    }
    
    let actionType: ActionType
    private let background: SKShapeNode
    private let label: SKLabelNode
    private var cooldownOverlay: SKShapeNode?
    
    var isOnCooldown: Bool = false
    var cooldownRemaining: TimeInterval = 0
    
    private let buttonRadius: CGFloat = 35
    
    init(type: ActionType) {
        self.actionType = type
        
        // 按钮背景
        background = SKShapeNode(circleOfRadius: buttonRadius)
        background.fillColor = SKColor.blue.withAlphaComponent(0.6)
        background.strokeColor = .white
        background.lineWidth = 3
        background.zPosition = 200
        
        // 按钮文字
        label = SKLabelNode(text: type.rawValue)
        label.fontSize = 20
        label.fontName = "AvenirNext-Bold"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 201
        
        super.init()
        
        addChild(background)
        addChild(label)
        
        name = "actionButton_\(type.rawValue)"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func isPointInside(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent!)
        return hypot(localPoint.x, localPoint.y) <= buttonRadius
    }
    
    func startCooldown(duration: TimeInterval) {
        isOnCooldown = true
        cooldownRemaining = duration
        background.fillColor = SKColor.gray.withAlphaComponent(0.4)
    }
    
    func updateCooldown(deltaTime: TimeInterval) {
        guard isOnCooldown else { return }
        cooldownRemaining -= deltaTime
        if cooldownRemaining <= 0 {
            cooldownRemaining = 0
            isOnCooldown = false
            background.fillColor = SKColor.blue.withAlphaComponent(0.6)
        }
    }
}
