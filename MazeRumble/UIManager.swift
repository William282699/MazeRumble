//
//  UIManager.swift
//  MazeRumble
//
//  Created by ChatGPT on 2025-XX-XX.
//

import SpriteKit
import UIKit

final class UIManager {

    private weak var uiNode: SKNode?

    private(set) var scoreBoardLabel: SKLabelNode?
    private(set) var scoreBoardShadow: SKLabelNode?
    private(set) var scoreBoardBackground: SKShapeNode?
    private(set) var playerProgressTrack: SKShapeNode?
    private(set) var botProgressTrack: SKShapeNode?
    private(set) var playerProgressBar: SKSpriteNode?
    private(set) var botProgressBar: SKSpriteNode?
    private(set) var timerLabel: SKLabelNode?
    private(set) var hintLabel: SKLabelNode?
    private var itemSlot1: SKShapeNode?
    private var itemSlot2: SKShapeNode?
    private var itemLabel1: SKLabelNode?
    private var itemLabel2: SKLabelNode?

    init(uiNode: SKNode) {
        self.uiNode = uiNode
    }

    func createUI() {
        guard let uiNode else { return }

        let bg = SKShapeNode(rectOf: GameConfig.scoreBackgroundSize, cornerRadius: 18)
        bg.fillColor = UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.78)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.85)
        bg.lineWidth = 2.5
        bg.zPosition = 298
        bg.name = "scoreBoardBackground"
        uiNode.addChild(bg)
        scoreBoardBackground = bg

        let shadow = SKLabelNode(text: "核心未被拾取")
        shadow.fontSize = 32
        shadow.fontName = "AvenirNext-Bold"
        shadow.fontColor = UIColor.black.withAlphaComponent(0.55)
        shadow.position = CGPoint(x: 0, y: -2)
        shadow.zPosition = 299
        uiNode.addChild(shadow)
        scoreBoardShadow = shadow

        let board = SKLabelNode(text: "核心未被拾取")
        board.fontSize = 32
        board.fontName = "AvenirNext-Bold"
        board.fontColor = .white
        board.zPosition = 300
        board.horizontalAlignmentMode = .center
        board.verticalAlignmentMode = .center
        uiNode.addChild(board)
        scoreBoardLabel = board

        let playerTrack = SKShapeNode(rectOf: CGSize(width: GameConfig.progressBarWidth, height: GameConfig.progressBarHeight), cornerRadius: GameConfig.progressBarHeight / 2)
        playerTrack.fillColor = UIColor.white.withAlphaComponent(0.12)
        playerTrack.strokeColor = UIColor.white.withAlphaComponent(0.35)
        playerTrack.lineWidth = 1.5
        playerTrack.zPosition = 299
        uiNode.addChild(playerTrack)
        playerProgressTrack = playerTrack

        let playerFill = SKSpriteNode(color: UIColor(red: 0.15, green: 0.85, blue: 0.35, alpha: 0.9),
                                      size: CGSize(width: GameConfig.progressBarWidth, height: GameConfig.progressBarHeight))
        playerFill.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        playerFill.zPosition = 300
        playerTrack.addChild(playerFill)
        playerProgressBar = playerFill

        let botTrack = SKShapeNode(rectOf: CGSize(width: GameConfig.progressBarWidth, height: GameConfig.progressBarHeight), cornerRadius: GameConfig.progressBarHeight / 2)
        botTrack.fillColor = UIColor.white.withAlphaComponent(0.12)
        botTrack.strokeColor = UIColor.white.withAlphaComponent(0.35)
        botTrack.lineWidth = 1.5
        botTrack.zPosition = 299
        uiNode.addChild(botTrack)
        botProgressTrack = botTrack

        let botFill = SKSpriteNode(color: UIColor(red: 0.9, green: 0.25, blue: 0.35, alpha: 0.9),
                                   size: CGSize(width: GameConfig.progressBarWidth, height: GameConfig.progressBarHeight))
        botFill.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        botFill.zPosition = 300
        botTrack.addChild(botFill)
        botProgressBar = botFill

        let timer = SKLabelNode(text: "02:00")
        timer.fontSize = 30
        timer.fontName = "AvenirNext-Bold"
        timer.fontColor = .yellow
        timer.zPosition = 300
        timer.horizontalAlignmentMode = .center
        uiNode.addChild(timer)
        timerLabel = timer

        let hint = SKLabelNode(text: "靠近任意门带核心冲线，2分钟内决出胜负")
        hint.fontSize = 18
        hint.fontName = "AvenirNext-DemiBold"
        hint.fontColor = .yellow
        hint.zPosition = 300
        uiNode.addChild(hint)
        hintLabel = hint

        createInventoryUI()
    }

    func layoutUI(for sceneSize: CGSize) {
        let halfWidth = sceneSize.width / 2
        let halfHeight = sceneSize.height / 2

        let scoreY = halfHeight - 42
        let scorePos = CGPoint(x: 0, y: scoreY)
        scoreBoardBackground?.position = scorePos
        scoreBoardShadow?.position = CGPoint(x: scorePos.x, y: scorePos.y - 2)
        scoreBoardLabel?.position = scorePos

        let barY = scoreY - 22
        playerProgressTrack?.position = CGPoint(x: -GameConfig.scoreBackgroundSize.width / 2 + GameConfig.progressBarWidth / 2 + 14, y: barY)
        botProgressTrack?.position = CGPoint(x: GameConfig.scoreBackgroundSize.width / 2 - GameConfig.progressBarWidth / 2 - 14, y: barY)
        playerProgressBar?.position = CGPoint(x: -GameConfig.progressBarWidth / 2, y: 0)
        botProgressBar?.position = CGPoint(x: GameConfig.progressBarWidth / 2, y: 0)

        timerLabel?.position = CGPoint(x: 0, y: scoreY - 54)
        hintLabel?.position = CGPoint(x: 0, y: scoreY - 88)

        // 道具栏位置（左上角）
        let slotY = halfHeight - 50
        itemSlot1?.position = CGPoint(x: -halfWidth + 40, y: slotY)
        itemSlot2?.position = CGPoint(x: -halfWidth + 100, y: slotY)
    }

    func updateScoreBoard(coreHolder: Player?, players: [Player], coreHitCount: Int) {
        let holderName: String
        if let holder = coreHolder, let idx = players.firstIndex(of: holder) {
            if idx == 0 {
                holderName = "你持有核心 (被打\(coreHitCount)/\(GameConfig.dropHitsRequired)次)"
            } else {
                holderName = "Bot\(idx)持有核心 (被打\(coreHitCount)/\(GameConfig.dropHitsRequired)次)"
            }
        } else {
            holderName = "核心未被拾取"
        }

        scoreBoardLabel?.text = holderName
        scoreBoardShadow?.text = holderName
    }

    func updateTimerLabel(roundTimeRemaining: TimeInterval) {
        let minutes = Int(roundTimeRemaining) / 60
        let seconds = Int(roundTimeRemaining) % 60
        timerLabel?.text = String(format: "%02d:%02d", minutes, seconds)
    }

    func updateUI(coreHolder: Player?, players: [Player], coreHitCount: Int, roundTimeRemaining: TimeInterval) {
        updateTimerLabel(roundTimeRemaining: roundTimeRemaining)
        updateScoreBoard(coreHolder: coreHolder, players: players, coreHitCount: coreHitCount)
    }

    func showMessage(_ text: String, color: UIColor, sceneSize: CGSize) {
        guard let uiNode else { return }

        let label = SKLabelNode(text: text)
        label.fontSize = 22
        label.fontColor = color
        label.position = CGPoint(x: 0, y: sceneSize.height / 2 - 135)
        label.zPosition = 400
        uiNode.addChild(label)

        label.run(.sequence([
            .fadeIn(withDuration: 0.05),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
    }

    func updateInventoryUI(inventory: [Item.ItemType]) {
        // 槽位1
        if inventory.count > 0 {
            itemLabel1?.text = inventory[0].rawValue
            itemSlot1?.fillColor = Item.color(for: inventory[0]).withAlphaComponent(0.7)
        } else {
            itemLabel1?.text = ""
            itemSlot1?.fillColor = SKColor.black.withAlphaComponent(0.5)
        }
        
        // 槽位2
        if inventory.count > 1 {
            itemLabel2?.text = inventory[1].rawValue
            itemSlot2?.fillColor = Item.color(for: inventory[1]).withAlphaComponent(0.7)
        } else {
            itemLabel2?.text = ""
            itemSlot2?.fillColor = SKColor.black.withAlphaComponent(0.5)
        }
    }

    func getItemSlotPressed(at location: CGPoint) -> Int? {
        if let slot1 = itemSlot1, slot1.contains(location) {
            return 0
        }
        if let slot2 = itemSlot2, slot2.contains(location) {
            return 1
        }
        return nil
    }

    private func createInventoryUI() {
        guard let uiNode else { return }
        
        // 道具槽1（左上角位置，之后会在layoutUI中调整）
        let slot1 = SKShapeNode(rectOf: CGSize(width: 50, height: 50), cornerRadius: 8)
        slot1.fillColor = SKColor.black.withAlphaComponent(0.5)
        slot1.strokeColor = .white
        slot1.lineWidth = 2
        slot1.zPosition = 300
        slot1.name = "itemSlot1"
        uiNode.addChild(slot1)
        itemSlot1 = slot1
        
        let label1 = SKLabelNode(text: "")
        label1.fontSize = 24
        label1.fontName = "AvenirNext-Bold"
        label1.fontColor = .white
        label1.verticalAlignmentMode = .center
        label1.horizontalAlignmentMode = .center
        label1.zPosition = 301
        slot1.addChild(label1)
        itemLabel1 = label1
        
        // 道具槽2
        let slot2 = SKShapeNode(rectOf: CGSize(width: 50, height: 50), cornerRadius: 8)
        slot2.fillColor = SKColor.black.withAlphaComponent(0.5)
        slot2.strokeColor = .white
        slot2.lineWidth = 2
        slot2.zPosition = 300
        slot2.name = "itemSlot2"
        uiNode.addChild(slot2)
        itemSlot2 = slot2
        
        let label2 = SKLabelNode(text: "")
        label2.fontSize = 24
        label2.fontName = "AvenirNext-Bold"
        label2.fontColor = .white
        label2.verticalAlignmentMode = .center
        label2.horizontalAlignmentMode = .center
        label2.zPosition = 301
        slot2.addChild(label2)
        itemLabel2 = label2
    }
}
