//
//  BotAI.swift
//  MazeRumble
//
//  Created by ChatGPT on 2025-??-??.
//

import SpriteKit

final class BotAI {

    var coreHolder: Player?
    var isFinalDashTriggered: Bool = false

    func update(bots: [Player], target: CGPoint) {
        for bot in bots {
            guard let body = bot.physicsBody else { continue }

            let targetPosition: CGPoint
            if let holder = coreHolder, holder != bot {
                targetPosition = holder.position
            } else {
                targetPosition = target
            }

            let dx = targetPosition.x - bot.position.x
            let dy = targetPosition.y - bot.position.y
            let dist = hypot(dx, dy)

            var dir = CGVector.zero
            if dist > 20 {
                dir = CGVector(dx: dx / dist, dy: dy / dist)
            }

            let speedMultiplier: CGFloat = (isFinalDashTriggered && coreHolder == bot) ? GameConfig.finalDashSpeedMultiplier : 1.0
            let desiredSpeed = GameConfig.botMaxSpeed * speedMultiplier

            let desired = CGVector(dx: dir.dx * desiredSpeed,
                                   dy: dir.dy * desiredSpeed)

            let vx = body.velocity.dx + (desired.dx - body.velocity.dx) * GameConfig.botAccelLerp
            let vy = body.velocity.dy + (desired.dy - body.velocity.dy) * GameConfig.botAccelLerp
            body.velocity = CGVector(dx: vx, dy: vy)
        }
    }
}
