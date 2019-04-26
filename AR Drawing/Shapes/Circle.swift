//
//  Circle.swift
//  AR Drawing
//
//  Created by Shawn Ma on 4/16/19.
//  Copyright © 2019 Shawn Ma. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

class Circle: SCNNode {
    
    var centerNode: SCNNode?
    
    init(radius: CGFloat) {
        super.init()

        let stroke = Constants.shared.stroke
        let tube = SCNTube(innerRadius: radius, outerRadius: (radius + stroke), height: 0.001)
        tube.firstMaterial?.diffuse.contents = Constants.shared.black
        
        let node = SCNNode(geometry: tube)
        
        let plane = SCNPlane(width: radius * 2, height: radius * 2)
        plane.cornerRadius = radius * 2
        plane.firstMaterial?.diffuse.contents = Constants.shared.randomColor
        plane.firstMaterial?.isDoubleSided = true
        let planeNode = SCNNode(geometry: plane)
        
        // roate the node to face the camera
        node.rotation = SCNVector4Make(1, 0, 0, .pi / 2)
        
        self.addChildNode(node)
        self.addChildNode(planeNode)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
