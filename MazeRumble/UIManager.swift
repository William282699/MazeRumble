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
}
