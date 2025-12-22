//
//  InputController.swift
//  MazeRumble
//
//  Created by ChatGPT on 2025-XX-XX.
//

import SpriteKit

final class InputController {

    private weak var uiNode: SKNode?

    private(set) var joystick: SKShapeNode?
    private(set) var joystickKnob: SKShapeNode?
    private(set) var pushButton: ActionButton?
    private(set) var tackleButton: ActionButton?
    private var moveDirection = CGVector.zero
    private var isTouching = false

    var currentDirection: CGVector {
        moveDirection
    }

    init(uiNode: SKNode) {
        self.uiNode = uiNode
    }

    func createJoystick() {
        guard let uiNode else { return }

        let base = SKShapeNode(circleOfRadius: GameConfig.joystickBaseRadius)
        base.fillColor = SKColor.gray.withAlphaComponent(0.35)
        base.strokeColor = .white
        base.lineWidth = 2
        base.zPosition = 200
        uiNode.addChild(base)
        joystick = base

        let knob = SKShapeNode(circleOfRadius: GameConfig.joystickKnobRadius)
        knob.fillColor = SKColor.white.withAlphaComponent(0.65)
        knob.strokeColor = .black
        knob.lineWidth = 2
        knob.zPosition = 201
        uiNode.addChild(knob)
        joystickKnob = knob
    }

    func createActionButtons() {
        guard let uiNode else { return }

        let push = ActionButton(type: .push)
        push.zPosition = 200
        uiNode.addChild(push)
        pushButton = push

        let tackle = ActionButton(type: .tackle)
        tackle.zPosition = 200
        uiNode.addChild(tackle)
        tackleButton = tackle
    }

    func layoutJoystick(for sceneSize: CGSize) {
        let halfWidth = sceneSize.width / 2
        let halfHeight = sceneSize.height / 2

        if let base = joystick {
            base.position = CGPoint(x: -halfWidth + 110, y: -halfHeight + 130)
        }
        if let knob = joystickKnob, let base = joystick {
            knob.position = base.position
        }
    }

    func layoutActionButtons(for sceneSize: CGSize) {
        let halfWidth = sceneSize.width / 2
        let halfHeight = sceneSize.height / 2

        // 右下角，两个按钮垂直排列
        pushButton?.position = CGPoint(x: halfWidth - 60, y: -halfHeight + 180)
        tackleButton?.position = CGPoint(x: halfWidth - 60, y: -halfHeight + 100)
    }

    func handleTouchBegan(at location: CGPoint) {
        guard let base = joystick else { return }
        let distance = hypot(location.x - base.position.x, location.y - base.position.y)
        if distance <= GameConfig.joystickTouchRadius || (location.x < 0 && location.y < 0) {
            isTouching = true
            updateJoystick(with: location)
        }
    }

    func handleTouchMoved(at location: CGPoint) {
        guard isTouching else { return }
        updateJoystick(with: location)
    }

    func handleTouchEnded() {
        isTouching = false
        resetJoystick()
    }

    func updateActionButtons(deltaTime: TimeInterval) {
        pushButton?.updateCooldown(deltaTime: deltaTime)
        tackleButton?.updateCooldown(deltaTime: deltaTime)
    }

    func getActionButtonPressed(at location: CGPoint) -> ActionButton.ActionType? {
        if let push = pushButton, !push.isOnCooldown, push.contains(location) {
            return .push
        }
        if let tackle = tackleButton, !tackle.isOnCooldown, tackle.contains(location) {
            return .tackle
        }
        return nil
    }

    private func updateJoystick(with location: CGPoint) {
        guard let base = joystick, let knob = joystickKnob else { return }

        let dx = location.x - base.position.x
        let dy = location.y - base.position.y
        let dist = hypot(dx, dy)

        let maxDist = GameConfig.joystickBaseRadius

        if dist <= maxDist {
            knob.position = location
        } else {
            let a = atan2(dy, dx)
            knob.position = CGPoint(x: base.position.x + cos(a) * maxDist,
                                   y: base.position.y + sin(a) * maxDist)
        }

        if dist < GameConfig.joystickDeadZone {
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
}
