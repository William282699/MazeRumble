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
        
        if let view = self.view as! SKView? {
            // 创建场景
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            
            // 展示场景
            view.presentScene(scene)
            
            // 调试选项
            view.ignoresSiblingOrder = true
            view.showsFPS = true       // 显示帧率
            view.showsNodeCount = true // 显示节点数
            
           
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape  // 横屏
    }
}
