//
//  GameViewController.swift
//  MazeRumble
//
//  Created by Yuqiao Huang on 2025-12-19.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = self.view as? SKView else { return }

        // ✅ 用代码创建 scene，避免 .sks 的尺寸/anchorPoint/scaleMode 问题
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill

        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true

        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsPhysics = false
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}
