//
//  ARSceneViewController + Extensions.swift
//  AR Drawing
//
//  Created by Shawn Ma on 4/28/19.
//  Copyright © 2019 Shawn Ma. All rights reserved.
//

import ARKit
import SnapKit
import ARVideoKit
import SCNLine

extension ARSceneViewController {
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        statusView.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusView.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusView.cancelScheduledMessage(for: .trackingStateEscalation)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if screenDown {
//            addSphere()
            addPoint()
        }
    }
}
//MARK:- Points and node positions(SCNVector3)
extension ARSceneViewController {
    
    // Push points into array for testing or classification
    private func addPoint(pointPos: (x: Float, y: Float)) -> Bool {
        let point = Point(x: pointPos.x, y: pointPos.y, strokeID: self.strokeIDCount)
        guard !point.x.isNaN, !point.y.isNaN else { return false }

        if !self.testingMode {
            if self.templatePoints[self.templatePoints.count - 1].isEmpty {
                self.templatePoints[self.templatePoints.count - 1].append(point)
                addInterestNode(id: self.strokeIDCount)
            } else {
                let lastPoint = self.templatePoints[self.templatePoints.count - 1].last
                let distance = Point.distanceBetween(pointA: point, pointB: lastPoint!)
                
                if distance > self.pointsDistanceThreshold {
                    self.templatePoints[self.templatePoints.count - 1].append(point)
                    addInterestNode(id: self.strokeIDCount)
                } else {
                    return false
                }
            }
        } else {
            if self.testingPoints.isEmpty {
                self.testingPoints.append(point)
                addInterestNode(id: self.strokeIDCount)
            } else {
                let lastPoint = self.testingPoints.last
                let distance = Point.distanceBetween(pointA: point, pointB: lastPoint!)
                
                if distance > self.pointsDistanceThreshold {
                    self.testingPoints.append(point)
                    addInterestNode(id: self.strokeIDCount)
                } else {
                    return false
                }
            }
        }
        return true
    }
    
    private func addInterestNode(id: Int) {
        if interestNodePositions[id] == nil {interestNodePositions[id] = []}
        
        guard let startNode = self.startNode else {return}
        let pointerNode = Service.shared.getPointerNode(inView: self.arView)
        let target = Service.shared.transformPosition(originNode: startNode, targetNode: pointerNode!)
        interestNodePositions[id]?.append(target)
    }

    
    // called by gesture recognizer
    @objc
    func tapHandler(gesture: UILongPressGestureRecognizer) {
        // handle touch down and touch up events separately
        if gesture.state == .began {
            screenTouchDown()
        } else if gesture.state == .ended {
            screenTouchUp()
        }
    }
    
    @objc
    func screenTouchDown() {
        self.hideDots()
        
        if !testingMode {
            templatePoints.append([])
        }
        DispatchQueue.main.async {
          let viewCenter = CGPoint(x: self.arView.frame.width / 2, y: self.arView.frame.height / 2)
          self.viewCenter = viewCenter
          guard let hitPosition = self.positionInScene(point: viewCenter) else {
              return
          }
          self.lastPosition = hitPosition

          self.startNode = Service.shared.getPointerNode(inView: self.arView)
          let drawingNode = SCNLineNode(with: [hitPosition], radius: 0.002, edges: 12, maxTurning: 12)
          drawingNode.lineMaterials.first?.diffuse.contents = UIColor.black
          drawingNode.lineMaterials.first?.isDoubleSided = true
          self.arView.scene.rootNode.addChildNode(drawingNode)
          self.drawingNode = drawingNode
          self.screenDown = true
        }
    }
    
    @objc
    func screenTouchUp() {
        screenDown = false
        self.hideDots()
        if testingMode {
            
            guard let shapes = templateShapes else {return}
            
            // Make sure there are enough sampling points
            guard self.testingPoints.count > 3 else {
                statusView.showMessage("Slow down, and try a larger shape", autoHide: true)
                return
            }
            
            let shape = Shape(points: self.testingPoints, type: .test)
            
            let resultType = QPointCloudRecognizer.classify(inputShape: shape, templateSet: shapes)
            self.typeString = resultType.rawValue
            
            let target = Shape(points: self.testingPoints, type: resultType)
            
            // Make sure there are enough sample points for configuring shapes
            switch target.type {
            case .rectangle, .triangle:
                guard target.originalPoints.count >= 6 else {
                    statusView.showMessage("Slow down, and try a larger shape", autoHide: true)
                    return}
                break
            default:
                guard target.originalPoints.count >= 3 else {
                    statusView.showMessage("Slow down, and try a larger shape", autoHide: true)
                    return}
            }
            
            add3DShapeToScene(templateSet: shapes, targetShape: target, strokeId: strokeIDCount)
            
            self.testingPoints = []
        } else {
            
            let latestPoints = templatePoints.filter({$0.count != 0}).last
            guard latestPoints!.count > 3 else {return}
            
            let latestShape = Shape(points: latestPoints!, type: self.currentType)
            if templateShapes == nil {
                templateShapes = []
            }
            
            
            // Make sure there are enough sample points for configuring shapes
            switch latestShape.type {
            case .rectangle, .triangle:
                guard latestShape.originalPoints.count >= 6 else {return}
                break
            default:
                guard latestShape.originalPoints.count >= 3 else {return}
            }
            
            templateShapes?.append(latestShape)
            guard let shapes = templateShapes else {return}
            
            add3DShapeToScene(templateSet: shapes, targetShape: latestShape, strokeId: strokeIDCount)
            
            Service.shared.saveShapeToFile(shape: templateShapes)
        }
        startNode = nil
        drawingNode?.removeFromParentNode()
        drawingNode = nil
    }
}

//MARK: - SCNNode actions here
extension ARSceneViewController {
    
    func addSphere() {
        let sphere = SCNNode()
        sphere.name = "penNode"
        sphere.geometry = SCNSphere(radius: 0.0015)
        sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(1)
        
        sphere.runAction(.fadeOut(duration: 4))
        sphere.runAction(.scale(to: 0, duration: 4))
        
        guard let startNode = self.startNode else {return}
        
        let position = Service.shared.to2D(originNode: startNode, inView: self.arView)
        
        if self.addPoint(pointPos: position) {
            Service.shared.addNode(sphere, toNode: self.scene.rootNode, inView: self.arView, cameraRelativePosition: self.cameraRelativePosition)
        }
    }

    /// Use hidden plane attached to the camera to get the position it hits the scene.
    /// This could be used to take the touch from anywhere on the screen, not just the centre.
    ///
    /// - Parameter point: point where the tap on the screen is taken from
    /// - Returns: Position in the scene graph where the touch hits
    func positionInScene(point: CGPoint) -> SCNVector3? {
        let hitPosition = self.arView.hitTest(point, options: [
            SCNHitTestOption.rootNode: cameraFrameNode, SCNHitTestOption.ignoreHiddenNodes: false
        ]).first
        return hitPosition?.worldCoordinates
    }

    /// Add point to the line the user is currently drawing
    func addPoint() {
        guard let viewCenter = self.viewCenter else {
            return
        }
        guard let hitPosition = positionInScene(point: viewCenter),
          let lastPos = self.lastPosition, lastPos.distance(vector: hitPosition) > 0.01,
          let startNode = self.startNode, let drawingNode = self.drawingNode else {
              return
        }
        self.lastPosition = lastPos
        let position = Service.shared.to2D(originNode: startNode, inView: self.arView)

        if self.addPoint(pointPos: position) {
            drawingNode.add(point: hitPosition)
        }
    }
    
    public func add3DShapeToScene(templateSet shapes: [Shape], targetShape shape: Shape, strokeId: Int) {
        let type = QPointCloudRecognizer.classify(inputShape: shape, templateSet: shapes)
        let count = shapes.filter({$0.type == type}).count - 1
        
        DispatchQueue.main.async {
            self.infoLabel.text = self.testingMode ? "This is a \(type)" : "\(type):\(count) added"
            Service.shared.fadeViewInThenOut(view: self.infoLabel, delay: 0.1)
        }
        
        log.debug(type)
        
        let currentStroke = strokeId
        
        let pointerNode = Service.shared.getPointerNode(inView: self.arView)!
        let centerNode = Service.shared.getShapeCenterNode(originNode: self.startNode!, nodePositions: self.interestNodePositions[strokeId]!, targetNode: pointerNode)
        
        if let node = Service.shared.get3DShapeNode(forShape: shape, nodePositions:
            
            self.interestNodePositions[currentStroke]!) {
            
            if shape.type == .line {
                let target = node as! Line
                node.eulerAngles.z -= target.angle
            }

            centerNode.childNodes.first?.addChildNode(node)
            Service.shared.addNode(centerNode, toNode: self.scene.rootNode, inView: self.arView, cameraRelativePosition: self.cameraRelativePosition)
            
            let shouldSetHeightlighted = Float.random(in: 0 ... 1)
            if shouldSetHeightlighted <= 0.3 {
                centerNode.setHighlighted()
            }
        } else {
            statusView.showMessage("Hints: line, circle, rectangle, triangle", autoHide: true)
        }
        
        // Increase stroke ID when adding template shape action or testing shape action is done
        strokeIDCount += 1
    }
    
    
    public func hideDots() {
        let dots = self.scene.rootNode.childNodes.filter({$0.name == "penNode"})
        dots.forEach { (dot) in
            DispatchQueue.main.async {
                dot.removeFromParentNode()
            }
        }
    }
}
