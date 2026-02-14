import SwiftUI
import ARKit
import SceneKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var tracker: ARFaceTracker
    @ObservedObject var wigManager: WigManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = true
        
        // Setup scene
        let scene = SCNScene()
        arView.scene = scene
        
        // Configure AR session
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking not supported on this device")
            return arView
        }
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Store reference
        tracker.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update wig when selection changes
        context.coordinator.updateWig(wigManager.currentWig)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tracker: tracker, wigManager: wigManager)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        var tracker: ARFaceTracker
        var wigManager: WigManager
        var wigNode: SCNNode?
        var currentWigID: String?
        
        init(tracker: ARFaceTracker, wigManager: WigManager) {
            self.tracker = tracker
            self.wigManager = wigManager
            super.init()
        }
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return nil }
            
            let faceNode = SCNNode()
            
            // Add wig node
            if let wig = wigManager.currentWig {
                wigNode = createWigNode(for: wig)
                if let wigNode = wigNode {
                    faceNode.addChildNode(wigNode)
                }
            }
            
            return faceNode
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }
            
            DispatchQueue.main.async {
                self.tracker.isFaceDetected = true
            }
            
            // Update wig position based on face transform
            updateWigTransform(for: faceAnchor)
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            DispatchQueue.main.async {
                self.tracker.isFaceDetected = false
            }
        }
        
        // MARK: - Wig Management
        
        func createWigNode(for wig: Wig) -> SCNNode? {
            guard let url = wig.modelURL else { return nil }
            
            do {
                let scene = try SCNScene(url: url, options: nil)
                let wigNode = SCNNode()
                
                for child in scene.rootNode.childNodes {
                    wigNode.addChildNode(child.clone())
                }
                
                // Position on top of head
                wigNode.position = SCNVector3(0, 0.08, 0.02)  // Adjust for head top
                wigNode.scale = SCNVector3(
                    wigManager.scale,
                    wigManager.scale,
                    wigManager.scale
                )
                
                // Apply material
                wigNode.enumerateChildNodes { (node, _) in
                    node.geometry?.materials.forEach { material in
                        material.lightingModel = .physicallyBased
                        material.roughness.contents = 0.6
                        material.metalness.contents = 0.0
                    }
                }
                
                currentWigID = wig.id
                return wigNode
                
            } catch {
                print("Failed to load wig model: \(error)")
                return nil
            }
        }
        
        func updateWig(_ wig: Wig?) {
            guard let wig = wig, wig.id != currentWigID else { return }
            
            // Remove old wig
            wigNode?.removeFromParentNode()
            
            // Add new wig
            if let newWigNode = createWigNode(for: wig) {
                // Find face node and add wig
                if let faceNode = tracker.arView?.scene.rootNode.childNodes.first(where: { node in
                    node.anchor is ARFaceAnchor
                }) {
                    faceNode.addChildNode(newWigNode)
                    wigNode = newWigNode
                }
            }
        }
        
        func updateWigTransform(for faceAnchor: ARFaceAnchor) {
            guard let wigNode = wigNode else { return }
            
            // Apply user adjustments
            let basePosition = SCNVector3(0, 0.08, 0.02)
            wigNode.position = SCNVector3(
                basePosition.x + Float(wigManager.offsetX),
                basePosition.y + Float(wigManager.offsetY),
                basePosition.z
            )
            
            let scale = Float(wigManager.scale)
            wigNode.scale = SCNVector3(scale, scale, scale)
        }
    }
}
