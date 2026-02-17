import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO

/// Loads GLB (binary glTF) files into SceneKit scenes.
/// Parses the GLB binary format and extracts meshes, materials, and textures.
class GLBSceneLoader {

    enum GLBError: Error {
        case invalidFile
        case invalidHeader
        case invalidChunk
        case noJSONChunk
        case parseError(String)
    }

    // MARK: - GLB Binary Format Constants
    private static let glbMagic: UInt32 = 0x46546C67 // "glTF"
    private static let jsonChunkType: UInt32 = 0x4E4F534A // "JSON"
    private static let binChunkType: UInt32 = 0x004E4942 // "BIN\0"

    // MARK: - Public API

    static func loadScene(from url: URL) throws -> SCNScene {
        let data = try Data(contentsOf: url)
        return try loadScene(from: data)
    }

    static func loadScene(from data: Data) throws -> SCNScene {
        let (json, binData) = try parseGLB(data)
        return try buildScene(json: json, binData: binData)
    }

    // MARK: - GLB Parsing

    private static func parseGLB(_ data: Data) throws -> ([String: Any], Data?) {
        guard data.count >= 12 else { throw GLBError.invalidHeader }

        let magic = data.readUInt32(at: 0)
        guard magic == glbMagic else { throw GLBError.invalidHeader }

        // version at offset 4, length at offset 8
        var offset = 12
        var jsonData: Data?
        var binData: Data?

        while offset < data.count {
            guard offset + 8 <= data.count else { break }
            let chunkLength = Int(data.readUInt32(at: offset))
            let chunkType = data.readUInt32(at: offset + 4)
            offset += 8

            guard offset + chunkLength <= data.count else { throw GLBError.invalidChunk }
            let chunkData = data.subdata(in: offset..<(offset + chunkLength))

            if chunkType == jsonChunkType {
                jsonData = chunkData
            } else if chunkType == binChunkType {
                binData = chunkData
            }

            offset += chunkLength
        }

        guard let jData = jsonData,
              let jsonObj = try JSONSerialization.jsonObject(with: jData) as? [String: Any] else {
            throw GLBError.noJSONChunk
        }

        return (jsonObj, binData)
    }

    // MARK: - Scene Building

    private static func buildScene(json: [String: Any], binData: Data?) throws -> SCNScene {
        let scene = SCNScene()

        let bufferViews = json["bufferViews"] as? [[String: Any]] ?? []
        let accessors = json["accessors"] as? [[String: Any]] ?? []
        let meshes = json["meshes"] as? [[String: Any]] ?? []
        let nodes = json["nodes"] as? [[String: Any]] ?? []
        let materials = json["materials"] as? [[String: Any]] ?? []
        let textures = json["textures"] as? [[String: Any]] ?? []
        let images = json["images"] as? [[String: Any]] ?? []
        let scenes = json["scenes"] as? [[String: Any]] ?? []
        let sceneIndex = json["scene"] as? Int ?? 0

        // Load images from binary data
        let loadedImages = loadImages(images: images, bufferViews: bufferViews, binData: binData)

        // Build SCNMaterials
        let scnMaterials = buildMaterials(materials: materials, textures: textures, loadedImages: loadedImages)

        // Build all nodes
        var scnNodes: [SCNNode] = []
        for node in nodes {
            let scnNode = try buildNode(
                node: node,
                meshes: meshes,
                accessors: accessors,
                bufferViews: bufferViews,
                binData: binData,
                scnMaterials: scnMaterials
            )
            scnNodes.append(scnNode)
        }

        // Set up parent-child relationships
        for (i, node) in nodes.enumerated() {
            if let children = node["children"] as? [Int] {
                for childIndex in children {
                    if childIndex < scnNodes.count {
                        scnNodes[i].addChildNode(scnNodes[childIndex])
                    }
                }
            }
        }

        // Add root nodes from the scene
        if sceneIndex < scenes.count, let rootNodes = scenes[sceneIndex]["nodes"] as? [Int] {
            for nodeIndex in rootNodes {
                if nodeIndex < scnNodes.count {
                    scene.rootNode.addChildNode(scnNodes[nodeIndex])
                }
            }
        } else {
            // Fallback: add all top-level nodes
            for scnNode in scnNodes {
                if scnNode.parent == nil {
                    scene.rootNode.addChildNode(scnNode)
                }
            }
        }

        return scene
    }

    // MARK: - Node Building

    private static func buildNode(
        node: [String: Any],
        meshes: [[String: Any]],
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        binData: Data?,
        scnMaterials: [SCNMaterial]
    ) throws -> SCNNode {
        let scnNode = SCNNode()

        if let name = node["name"] as? String {
            scnNode.name = name
        }

        // Apply transform
        if let matrix = node["matrix"] as? [Double], matrix.count == 16 {
            scnNode.transform = SCNMatrix4(
                m11: Float(matrix[0]), m12: Float(matrix[1]), m13: Float(matrix[2]), m14: Float(matrix[3]),
                m21: Float(matrix[4]), m22: Float(matrix[5]), m23: Float(matrix[6]), m24: Float(matrix[7]),
                m31: Float(matrix[8]), m32: Float(matrix[9]), m33: Float(matrix[10]), m34: Float(matrix[11]),
                m41: Float(matrix[12]), m42: Float(matrix[13]), m43: Float(matrix[14]), m44: Float(matrix[15])
            )
        } else {
            if let translation = node["translation"] as? [Double], translation.count == 3 {
                scnNode.position = SCNVector3(Float(translation[0]), Float(translation[1]), Float(translation[2]))
            }
            if let rotation = node["rotation"] as? [Double], rotation.count == 4 {
                scnNode.orientation = SCNQuaternion(Float(rotation[0]), Float(rotation[1]), Float(rotation[2]), Float(rotation[3]))
            }
            if let scale = node["scale"] as? [Double], scale.count == 3 {
                scnNode.scale = SCNVector3(Float(scale[0]), Float(scale[1]), Float(scale[2]))
            }
        }

        // Build mesh
        if let meshIndex = node["mesh"] as? Int, meshIndex < meshes.count {
            let mesh = meshes[meshIndex]
            if let primitives = mesh["primitives"] as? [[String: Any]] {
                for primitive in primitives {
                    if let geometry = try buildGeometry(
                        primitive: primitive,
                        accessors: accessors,
                        bufferViews: bufferViews,
                        binData: binData,
                        scnMaterials: scnMaterials
                    ) {
                        let childNode = SCNNode(geometry: geometry)
                        scnNode.addChildNode(childNode)
                    }
                }
            }
        }

        return scnNode
    }

    // MARK: - Geometry Building

    private static func buildGeometry(
        primitive: [String: Any],
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        binData: Data?,
        scnMaterials: [SCNMaterial]
    ) throws -> SCNGeometry? {
        guard let attributes = primitive["attributes"] as? [String: Int] else { return nil }

        var sources: [SCNGeometrySource] = []
        var element: SCNGeometryElement?

        // Position
        if let posIndex = attributes["POSITION"] {
            if let source = buildGeometrySource(
                accessorIndex: posIndex,
                semantic: .vertex,
                accessors: accessors,
                bufferViews: bufferViews,
                binData: binData
            ) {
                sources.append(source)
            }
        }

        // Normal
        if let normalIndex = attributes["NORMAL"] {
            if let source = buildGeometrySource(
                accessorIndex: normalIndex,
                semantic: .normal,
                accessors: accessors,
                bufferViews: bufferViews,
                binData: binData
            ) {
                sources.append(source)
            }
        }

        // Texture coordinates
        if let texIndex = attributes["TEXCOORD_0"] {
            if let source = buildGeometrySource(
                accessorIndex: texIndex,
                semantic: .texcoord,
                accessors: accessors,
                bufferViews: bufferViews,
                binData: binData
            ) {
                sources.append(source)
            }
        }

        // Indices
        if let indicesIndex = primitive["indices"] as? Int {
            element = buildGeometryElement(
                accessorIndex: indicesIndex,
                accessors: accessors,
                bufferViews: bufferViews,
                binData: binData
            )
        }

        guard !sources.isEmpty else { return nil }

        let elements: [SCNGeometryElement]
        if let element = element {
            elements = [element]
        } else {
            // No indices — build a trivial element for the vertex count
            let vertexCount = sources.first?.vectorCount ?? 0
            elements = [SCNGeometryElement(
                data: nil,
                primitiveType: .triangles,
                primitiveCount: vertexCount / 3,
                bytesPerIndex: 0
            )]
        }

        let geometry = SCNGeometry(sources: sources, elements: elements)

        // Apply material
        if let matIndex = primitive["material"] as? Int, matIndex < scnMaterials.count {
            geometry.materials = [scnMaterials[matIndex]]
        } else {
            let defaultMat = SCNMaterial()
            defaultMat.lightingModel = .physicallyBased
            defaultMat.diffuse.contents = UIColor.gray
            geometry.materials = [defaultMat]
        }

        return geometry
    }

    private static func buildGeometrySource(
        accessorIndex: Int,
        semantic: SCNGeometrySource.Semantic,
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        binData: Data?
    ) -> SCNGeometrySource? {
        guard accessorIndex < accessors.count else { return nil }
        let accessor = accessors[accessorIndex]

        guard let bufferViewIndex = accessor["bufferView"] as? Int,
              bufferViewIndex < bufferViews.count,
              let binData = binData else { return nil }

        let bufferView = bufferViews[bufferViewIndex]
        let byteOffset = (bufferView["byteOffset"] as? Int ?? 0) + (accessor["byteOffset"] as? Int ?? 0)
        let count = accessor["count"] as? Int ?? 0
        let componentType = accessor["componentType"] as? Int ?? 5126 // FLOAT
        let type = accessor["type"] as? String ?? "VEC3"

        let componentsPerVector: Int
        switch type {
        case "SCALAR": componentsPerVector = 1
        case "VEC2": componentsPerVector = 2
        case "VEC3": componentsPerVector = 3
        case "VEC4": componentsPerVector = 4
        default: return nil
        }

        let bytesPerComponent: Int
        let floatComponents: Bool
        switch componentType {
        case 5120: bytesPerComponent = 1; floatComponents = false  // BYTE
        case 5121: bytesPerComponent = 1; floatComponents = false  // UNSIGNED_BYTE
        case 5122: bytesPerComponent = 2; floatComponents = false  // SHORT
        case 5123: bytesPerComponent = 2; floatComponents = false  // UNSIGNED_SHORT
        case 5125: bytesPerComponent = 4; floatComponents = false  // UNSIGNED_INT
        case 5126: bytesPerComponent = 4; floatComponents = true   // FLOAT
        default: return nil
        }

        let stride = bufferView["byteStride"] as? Int ?? (bytesPerComponent * componentsPerVector)
        let length = count * stride

        guard byteOffset + length <= binData.count else { return nil }

        let data = binData.subdata(in: byteOffset..<(byteOffset + length))

        return SCNGeometrySource(
            data: data,
            semantic: semantic,
            vectorCount: count,
            usesFloatComponents: floatComponents,
            componentsPerVector: componentsPerVector,
            bytesPerComponent: bytesPerComponent,
            dataOffset: 0,
            dataStride: stride
        )
    }

    private static func buildGeometryElement(
        accessorIndex: Int,
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        binData: Data?
    ) -> SCNGeometryElement? {
        guard accessorIndex < accessors.count else { return nil }
        let accessor = accessors[accessorIndex]

        guard let bufferViewIndex = accessor["bufferView"] as? Int,
              bufferViewIndex < bufferViews.count,
              let binData = binData else { return nil }

        let bufferView = bufferViews[bufferViewIndex]
        let byteOffset = (bufferView["byteOffset"] as? Int ?? 0) + (accessor["byteOffset"] as? Int ?? 0)
        let count = accessor["count"] as? Int ?? 0
        let componentType = accessor["componentType"] as? Int ?? 5123

        let bytesPerIndex: Int
        switch componentType {
        case 5121: bytesPerIndex = 1  // UNSIGNED_BYTE
        case 5123: bytesPerIndex = 2  // UNSIGNED_SHORT
        case 5125: bytesPerIndex = 4  // UNSIGNED_INT
        default: bytesPerIndex = 2
        }

        let length = count * bytesPerIndex
        guard byteOffset + length <= binData.count else { return nil }

        let data = binData.subdata(in: byteOffset..<(byteOffset + length))

        return SCNGeometryElement(
            data: data,
            primitiveType: .triangles,
            primitiveCount: count / 3,
            bytesPerIndex: bytesPerIndex
        )
    }

    // MARK: - Image Loading

    private static func loadImages(
        images: [[String: Any]],
        bufferViews: [[String: Any]],
        binData: Data?
    ) -> [UIImage?] {
        return images.map { image -> UIImage? in
            guard let bufferViewIndex = image["bufferView"] as? Int,
                  bufferViewIndex < bufferViews.count,
                  let binData = binData else { return nil }

            let bufferView = bufferViews[bufferViewIndex]
            let byteOffset = bufferView["byteOffset"] as? Int ?? 0
            let byteLength = bufferView["byteLength"] as? Int ?? 0

            guard byteOffset + byteLength <= binData.count else { return nil }

            let imageData = binData.subdata(in: byteOffset..<(byteOffset + byteLength))
            return UIImage(data: imageData)
        }
    }

    // MARK: - Material Building

    private static func buildMaterials(
        materials: [[String: Any]],
        textures: [[String: Any]],
        loadedImages: [UIImage?]
    ) -> [SCNMaterial] {
        return materials.map { mat -> SCNMaterial in
            let scnMat = SCNMaterial()
            scnMat.lightingModel = .physicallyBased

            // PBR metallic-roughness
            if let pbr = mat["pbrMetallicRoughness"] as? [String: Any] {
                // Base color
                if let baseColorTexture = pbr["baseColorTexture"] as? [String: Any],
                   let texIndex = baseColorTexture["index"] as? Int,
                   texIndex < textures.count {
                    let texture = textures[texIndex]
                    if let sourceIndex = texture["source"] as? Int,
                       sourceIndex < loadedImages.count,
                       let image = loadedImages[sourceIndex] {
                        scnMat.diffuse.contents = image
                    }
                } else if let baseColorFactor = pbr["baseColorFactor"] as? [Double], baseColorFactor.count >= 4 {
                    scnMat.diffuse.contents = UIColor(
                        red: CGFloat(baseColorFactor[0]),
                        green: CGFloat(baseColorFactor[1]),
                        blue: CGFloat(baseColorFactor[2]),
                        alpha: CGFloat(baseColorFactor[3])
                    )
                }

                // Metallic & roughness
                let metallicFactor = pbr["metallicFactor"] as? Double ?? 1.0
                let roughnessFactor = pbr["roughnessFactor"] as? Double ?? 1.0
                scnMat.metalness.contents = metallicFactor
                scnMat.roughness.contents = roughnessFactor

                // Metallic-roughness texture
                if let mrTexture = pbr["metallicRoughnessTexture"] as? [String: Any],
                   let texIndex = mrTexture["index"] as? Int,
                   texIndex < textures.count {
                    let texture = textures[texIndex]
                    if let sourceIndex = texture["source"] as? Int,
                       sourceIndex < loadedImages.count,
                       let image = loadedImages[sourceIndex] {
                        scnMat.metalness.contents = image
                        scnMat.roughness.contents = image
                    }
                }
            }

            // Normal map
            if let normalTexture = mat["normalTexture"] as? [String: Any],
               let texIndex = normalTexture["index"] as? Int,
               texIndex < textures.count {
                let texture = textures[texIndex]
                if let sourceIndex = texture["source"] as? Int,
                   sourceIndex < loadedImages.count,
                   let image = loadedImages[sourceIndex] {
                    scnMat.normal.contents = image
                }
            }

            // Emissive
            if let emissiveTexture = mat["emissiveTexture"] as? [String: Any],
               let texIndex = emissiveTexture["index"] as? Int,
               texIndex < textures.count {
                let texture = textures[texIndex]
                if let sourceIndex = texture["source"] as? Int,
                   sourceIndex < loadedImages.count,
                   let image = loadedImages[sourceIndex] {
                    scnMat.emission.contents = image
                }
            }

            // Alpha mode
            if let alphaMode = mat["alphaMode"] as? String {
                switch alphaMode {
                case "BLEND":
                    scnMat.isDoubleSided = true
                    scnMat.transparencyMode = .aOne
                case "MASK":
                    scnMat.isDoubleSided = true
                default:
                    break
                }
            }

            if mat["doubleSided"] as? Bool == true {
                scnMat.isDoubleSided = true
            }

            return scnMat
        }
    }
}

// MARK: - Data Extension for Binary Reading

private extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self)
        }
    }
}
