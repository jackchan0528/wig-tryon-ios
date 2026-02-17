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
        var faceNode: SCNNode?
        var faceOcclusionNode: SCNNode?  // ARKit face mesh occluder
        var currentWigID: String?

        // Computed once per model load — the scale that maps the model to head size
        var baseScale: Float = 1.0
        // The offset to center the model's bowl opening on the head
        var baseOffset: SCNVector3 = SCNVector3Zero

        // ARKit face anchor reference measurements (meters)
        // Origin is at the bridge of the nose / between the eyes
        static let headWidth: Float = 0.18        // temple-to-temple
        static let crownAboveAnchor: Float = 0.11  // top of skull above face anchor
        static let skullCenterZ: Float = -0.08     // center of skull behind face anchor

        // Shared occlusion material — invisible but writes to depth buffer
        static let occlusionMaterial: SCNMaterial = {
            let mat = SCNMaterial()
            mat.colorBufferWriteMask = []   // no visible pixels
            mat.writesToDepthBuffer = true   // blocks things behind it
            return mat
        }()

        init(tracker: ARFaceTracker, wigManager: WigManager) {
            self.tracker = tracker
            self.wigManager = wigManager
            super.init()
        }

        // MARK: - ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor else { return nil }

            let node = SCNNode()
            faceNode = node

            // --- Occlusion geometry: invisible "head" that hides the back of the wig ---

            // 1. ARKit face mesh — precise occluder for the face area
            if let device = MTLCreateSystemDefaultDevice(),
               let faceGeometry = ARSCNFaceGeometry(device: device) {
                faceGeometry.materials = [Self.occlusionMaterial]
                let faceOccNode = SCNNode(geometry: faceGeometry)
                faceOccNode.renderingOrder = -1
                node.addChildNode(faceOccNode)
                faceOcclusionNode = faceOccNode
            }

            // 2. Skull sphere — occluder for the back/top of the head
            let skull = SCNSphere(radius: 0.09)
            skull.segmentCount = 24
            skull.materials = [Self.occlusionMaterial]
            let skullNode = SCNNode(geometry: skull)
            // Positioned at skull center: slightly above nose bridge, well behind the face
            skullNode.position = SCNVector3(0, 0.04, Self.skullCenterZ)
            // Oval: taller than wide, deeper than wide
            skullNode.scale = SCNVector3(1.0, 1.2, 1.1)
            skullNode.renderingOrder = -1
            node.addChildNode(skullNode)

            // --- Wig ---
            if let wig = wigManager.currentWig {
                wigNode = createWigNode(for: wig)
                if let wigNode = wigNode {
                    node.addChildNode(wigNode)
                }
            }

            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }

            DispatchQueue.main.async {
                self.tracker.isFaceDetected = true
            }

            // Update face occlusion mesh to match current expression
            if let faceGeometry = faceOcclusionNode?.geometry as? ARSCNFaceGeometry {
                faceGeometry.update(from: faceAnchor.geometry)
            }

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
                let scene: SCNScene
                if url.pathExtension.lowercased() == "glb" {
                    scene = try GLBSceneLoader.loadScene(from: url)
                } else {
                    scene = try SCNScene(url: url, options: nil)
                }

                // Container that holds all model children
                let container = SCNNode()
                for child in scene.rootNode.childNodes {
                    container.addChildNode(child.clone())
                }

                // --- Measure the model's bounding box ---
                let (minVec, maxVec) = container.boundingBox
                let modelWidth  = maxVec.x - minVec.x
                let modelHeight = maxVec.y - minVec.y
                let modelDepth  = maxVec.z - minVec.z
                let modelCenterX = (minVec.x + maxVec.x) / 2
                let modelCenterZ = (minVec.z + maxVec.z) / 2
                let modelCenterY = (minVec.y + maxVec.y) / 2

                print("Wig model bounds: w=\(modelWidth) h=\(modelHeight) d=\(modelDepth)")
                print("Wig model center: x=\(modelCenterX) y=\(modelCenterY) z=\(modelCenterZ)")

                // --- Auto-scale so widest horizontal extent ≈ head width ---
                let maxHorizontal = max(modelWidth, modelDepth)
                guard maxHorizontal > 0 else { return nil }
                baseScale = Self.headWidth / maxHorizontal

                // --- Position: center the wig around the skull ---
                // Y: vertical center of wig at the crown
                // Z: center of wig at the center of the skull (well behind the face)
                baseOffset = SCNVector3(
                    -baseScale * modelCenterX,                         // center horizontally
                    Self.crownAboveAnchor - baseScale * modelCenterY,  // wig center at crown
                    Self.skullCenterZ - baseScale * modelCenterZ       // wig center at skull center
                )

                // Apply initial transform
                let s = baseScale * Float(wigManager.scale)
                container.scale = SCNVector3(s, s, s)
                container.position = SCNVector3(
                    baseOffset.x + Float(wigManager.offsetX),
                    baseOffset.y + Float(wigManager.offsetY),
                    baseOffset.z + Float(wigManager.offsetZ)
                )

                // For non-GLB files, apply default PBR material
                if url.pathExtension.lowercased() != "glb" {
                    container.enumerateChildNodes { (node, _) in
                        node.geometry?.materials.forEach { material in
                            material.lightingModel = .physicallyBased
                            material.roughness.contents = 0.6
                            material.metalness.contents = 0.0
                        }
                    }
                }

                // Render wig after occlusion geometry so depth test hides the back
                container.renderingOrder = 1
                container.enumerateChildNodes { child, _ in
                    child.renderingOrder = 1
                }

                currentWigID = wig.id
                return container

            } catch {
                print("Failed to load wig model: \(error)")
                return nil
            }
        }

        func updateWig(_ wig: Wig?) {
            guard let wig = wig, wig.id != currentWigID else { return }

            wigNode?.removeFromParentNode()

            if let newWigNode = createWigNode(for: wig) {
                if let faceNode = faceNode {
                    faceNode.addChildNode(newWigNode)
                    wigNode = newWigNode
                }
            }
        }

        func updateWigTransform(for faceAnchor: ARFaceAnchor) {
            guard let wigNode = wigNode else { return }

            // Use actual face geometry to refine head width
            let vertices = faceAnchor.geometry.vertices
            var minX: Float = .greatestFiniteMagnitude
            var maxX: Float = -.greatestFiniteMagnitude
            for v in vertices {
                minX = min(minX, v.x)
                maxX = max(maxX, v.x)
            }
            let measuredFaceWidth = maxX - minX  // face mesh width
            // Head (with hair) is wider than the face mesh — roughly 1.3×
            let estimatedHeadWidth = measuredFaceWidth * 1.3

            // Adjust base scale to match this particular face
            let faceAdjustedScale = baseScale * (estimatedHeadWidth / Self.headWidth)

            let s = faceAdjustedScale * Float(wigManager.scale)
            wigNode.scale = SCNVector3(s, s, s)

            // Recompute position with the adjusted scale
            wigNode.position = SCNVector3(
                baseOffset.x + Float(wigManager.offsetX),
                baseOffset.y + Float(wigManager.offsetY),
                baseOffset.z + Float(wigManager.offsetZ)
            )
        }
    }
}
