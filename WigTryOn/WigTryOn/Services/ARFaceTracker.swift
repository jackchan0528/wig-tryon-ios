import Foundation
import ARKit
import Combine

class ARFaceTracker: ObservableObject {
    @Published var isFaceDetected: Bool = false
    @Published var faceTransform: simd_float4x4?
    @Published var blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]?
    
    weak var arView: ARSCNView?
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let arView = arView else {
            completion(nil)
            return
        }
        
        // Capture snapshot
        let snapshot = arView.snapshot()
        completion(snapshot)
    }
    
    func resetTracking() {
        guard let arView = arView,
              ARFaceTrackingConfiguration.isSupported else { return }
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func pauseTracking() {
        arView?.session.pause()
    }
    
    func resumeTracking() {
        guard let arView = arView,
              ARFaceTrackingConfiguration.isSupported else { return }
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        
        arView.session.run(config)
    }
}

// MARK: - Face Data Extraction

extension ARFaceTracker {
    struct FaceData {
        let position: SIMD3<Float>
        let rotation: simd_quatf
        let leftEyePosition: SIMD3<Float>?
        let rightEyePosition: SIMD3<Float>?
        let headTop: SIMD3<Float>
    }
    
    func extractFaceData(from anchor: ARFaceAnchor) -> FaceData {
        let transform = anchor.transform
        
        // Extract position
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        // Extract rotation
        let rotation = simd_quatf(transform)
        
        // Eye positions (if available)
        let leftEye = anchor.leftEyeTransform.columns.3
        let rightEye = anchor.rightEyeTransform.columns.3
        
        // Estimate head top (above the face mesh)
        let headTop = SIMD3<Float>(
            position.x,
            position.y + 0.1,  // ~10cm above face center
            position.z
        )
        
        return FaceData(
            position: position,
            rotation: rotation,
            leftEyePosition: SIMD3<Float>(leftEye.x, leftEye.y, leftEye.z),
            rightEyePosition: SIMD3<Float>(rightEye.x, rightEye.y, rightEye.z),
            headTop: headTop
        )
    }
}
