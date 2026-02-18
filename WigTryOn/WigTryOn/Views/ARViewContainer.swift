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
        var faceOcclusionNode: SCNNode?   // ARKit face mesh occluder
        var skullOcclusionNode: SCNNode?  // Skull sphere occluder
        var neckOcclusionNode: SCNNode?   // Neck cylinder occluder
        var currentWigID: String?

        // --- Raw model measurements (set once per model load) ---
        // baseScale maps the model so its widest extent = referenceHeadWidth
        var baseScale: Float = 1.0
        var rawModelCenterX: Float = 0
        var rawModelCenterZ: Float = 0
        var rawInnerBowlY: Float = 0   // estimated inner bowl height in model space

        // Reference head width used to compute baseScale
        static let referenceHeadWidth: Float = 0.22

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
            //    Position and scale are set dynamically in updateWigTransform
            let skull = SCNSphere(radius: 0.09)
            skull.segmentCount = 24
            skull.materials = [Self.occlusionMaterial]
            let skullNode = SCNNode(geometry: skull)
            skullNode.position = SCNVector3(0, 0.04, -0.08)
            skullNode.scale = SCNVector3(1.0, 1.2, 1.1)
            skullNode.renderingOrder = -1
            node.addChildNode(skullNode)
            skullOcclusionNode = skullNode

            // 3. Neck cylinder — occluder for the neck area so back hair goes behind it
            let neck = SCNCylinder(radius: 0.05, height: 0.12)
            neck.radialSegmentCount = 16
            neck.materials = [Self.occlusionMaterial]
            let neckNode = SCNNode(geometry: neck)
            neckNode.position = SCNVector3(0, -0.06, -0.04)
            neckNode.renderingOrder = -1
            node.addChildNode(neckNode)
            neckOcclusionNode = neckNode

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

                let contentNode: SCNNode
                if url.pathExtension.lowercased() == "usdz" {
                    let correctionNode = SCNNode()
                    correctionNode.eulerAngles = SCNVector3(Float.pi * 1.5, 0, 0) // 270° (180° axis fix + 90° USDZ-specific tilt)
                    container.addChildNode(correctionNode)
                    contentNode = correctionNode
                } else {
                    contentNode = container
                }

                for child in scene.rootNode.childNodes {
                    contentNode.addChildNode(child.clone())
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

                // --- Auto-scale so widest horizontal extent ≈ reference head width ---
                let maxHorizontal = max(modelWidth, modelDepth)
                guard maxHorizontal > 0 else { return nil }
                baseScale = Self.referenceHeadWidth / maxHorizontal

                // --- Store raw model measurements for dynamic fitting ---
                rawModelCenterX = modelCenterX
                rawModelCenterZ = modelCenterZ
                rawInnerBowlY = (modelCenterY + maxVec.y) / 2  // ~75% up the bbox

                // Apply a default initial transform (will be overridden once face is detected)
                let s = baseScale * Float(wigManager.scale)
                container.scale = SCNVector3(s, s, s)
                container.position = SCNVector3(
                    -baseScale * rawModelCenterX,
                    0.11 - baseScale * rawInnerBowlY,
                    -0.08 - baseScale * rawModelCenterZ
                )
                container.eulerAngles = SCNVector3(
                    Float(wigManager.rotationX) * .pi / 180,
                    Float(wigManager.rotationY) * .pi / 180,
                    Float(wigManager.rotationZ) * .pi / 180
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

        // MARK: - Dynamic Face-Based Fitting

        func updateWigTransform(for faceAnchor: ARFaceAnchor) {
            guard let wigNode = wigNode else { return }

            // --- Measure the actual face from ARKit's mesh vertices ---
            let vertices = faceAnchor.geometry.vertices
            var minX: Float =  .greatestFiniteMagnitude
            var maxX: Float = -.greatestFiniteMagnitude
            var maxY: Float = -.greatestFiniteMagnitude
            for v in vertices {
                minX = min(minX, v.x)
                maxX = max(maxX, v.x)
                maxY = max(maxY, v.y)
            }

            let faceWidth   = maxX - minX   // measured face mesh width
            let foreheadTop = maxY           // highest point of the face mesh

            // --- Derive head dimensions proportionally from face ---
            // Head (with hair) is wider than the face mesh
            let headWidth = faceWidth * 1.8
            // Crown sits above the forehead, proportional to face size
            let crownY = foreheadTop + faceWidth * 0.30
            // Skull center depth behind the face anchor, proportional to face size
            let skullZ = -faceWidth * 0.55

            // --- Scale wig to fit this specific head ---
            let faceScale = baseScale * (headWidth / Self.referenceHeadWidth)
            let s = faceScale * Float(wigManager.scale)
            wigNode.scale = SCNVector3(s, s, s)

            // --- Position wig on this specific head ---
            wigNode.position = SCNVector3(
                -faceScale * rawModelCenterX + Float(wigManager.offsetX),
                crownY - faceScale * rawInnerBowlY + Float(wigManager.offsetY),
                skullZ - faceScale * rawModelCenterZ + Float(wigManager.offsetZ)
            )

            // Apply rotation (degrees → radians)
            wigNode.eulerAngles = SCNVector3(
                Float(wigManager.rotationX) * .pi / 180,
                Float(wigManager.rotationY) * .pi / 180,
                Float(wigManager.rotationZ) * .pi / 180
            )

            // --- Scale skull occlusion to match this face ---
            if let skullNode = skullOcclusionNode {
                let skullRadius = faceWidth * 0.65
                skullNode.position = SCNVector3(0, foreheadTop * 0.5, skullZ)
                // Normalize against the base sphere radius (0.09)
                let radiusScale = skullRadius / 0.09
                skullNode.scale = SCNVector3(
                    radiusScale,
                    radiusScale * 1.2,   // taller
                    radiusScale * 1.1    // deeper
                )
            }

            // --- Scale neck occlusion to match this face ---
            if let neckNode = neckOcclusionNode {
                let neckRadius = faceWidth * 0.45   // neck is narrower than skull
                let neckHeight = faceWidth * 1.5    // extends well below chin
                // Position: below the face anchor, slightly behind center
                neckNode.position = SCNVector3(0, -neckHeight * 0.4, skullZ * 0.5)
                // Normalize against the base cylinder (radius=0.05, height=0.12)
                let rScale = neckRadius / 0.05
                let hScale = neckHeight / 0.12
                neckNode.scale = SCNVector3(rScale, hScale, rScale)
            }
        }
    }
}
