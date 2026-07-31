import SceneKit
import simd

/// Builds flat-shaded, vertex-coloured geometry — the faceted low-poly look.
enum GeometryKit {

    /// Shared materials so vertex-coloured props merge into few draw calls.
    static let solidVertexMaterial: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = UIColor.white
        m.locksAmbientWithDiffuse = true
        return m
    }()

    static let foliageVertexMaterial: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = UIColor.white
        m.locksAmbientWithDiffuse = true
        m.isDoubleSided = true
        return m
    }()

    static func flatShaded(positions: [SIMD3<Float>], colors: [SIMD3<Float>],
                           material shared: SCNMaterial? = nil) -> SCNGeometry {
        precondition(positions.count == colors.count)
        let count = positions.count

        var normals = [SIMD3<Float>](repeating: .zero, count: count)
        var i = 0
        while i + 2 < count {
            let a = positions[i], b = positions[i + 1], c = positions[i + 2]
            var n = simd_cross(b - a, c - a)
            let len = simd_length(n)
            n = len > 1e-6 ? n / len : SIMD3(0, 1, 0)
            normals[i] = n; normals[i + 1] = n; normals[i + 2] = n
            i += 3
        }

        var verts = [Float]()
        verts.reserveCapacity(count * 3)
        var norms = [Float]()
        norms.reserveCapacity(count * 3)
        var cols = [Float]()
        cols.reserveCapacity(count * 4)
        for k in 0..<count {
            verts.append(positions[k].x); verts.append(positions[k].y); verts.append(positions[k].z)
            norms.append(normals[k].x); norms.append(normals[k].y); norms.append(normals[k].z)
            cols.append(colors[k].x); cols.append(colors[k].y); cols.append(colors[k].z); cols.append(1)
        }

        let vData = Data(bytes: verts, count: verts.count * MemoryLayout<Float>.size)
        let nData = Data(bytes: norms, count: norms.count * MemoryLayout<Float>.size)
        let cData = Data(bytes: cols, count: cols.count * MemoryLayout<Float>.size)

        let vSource = SCNGeometrySource(data: vData, semantic: .vertex, vectorCount: count,
                                        usesFloatComponents: true, componentsPerVector: 3,
                                        bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 3)
        let nSource = SCNGeometrySource(data: nData, semantic: .normal, vectorCount: count,
                                        usesFloatComponents: true, componentsPerVector: 3,
                                        bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 3)
        let cSource = SCNGeometrySource(data: cData, semantic: .color, vectorCount: count,
                                        usesFloatComponents: true, componentsPerVector: 4,
                                        bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 4)

        let indices = (0..<Int32(count)).map { $0 }
        let iData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: iData, primitiveType: .triangles,
                                         primitiveCount: count / 3,
                                         bytesPerIndex: MemoryLayout<Int32>.size)

        let geo = SCNGeometry(sources: [vSource, nSource, cSource], elements: [element])
        if let shared {
            geo.materials = [shared]
            return geo
        }
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        mat.diffuse.contents = UIColor.white
        mat.locksAmbientWithDiffuse = true
        mat.isDoubleSided = false
        geo.materials = [mat]
        return geo
    }

    /// A faceted blob — used for rocks, asteroids and boulders.
    static func blob(radius: Float, roughness: Float, color: SIMD3<Float>, seed: UInt64,
                     material: SCNMaterial? = nil) -> SCNGeometry {
        var rng = SeededRandom(seed)
        // Icosahedron vertices
        let t: Float = (1 + sqrt(5)) / 2
        var base: [SIMD3<Float>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1),
        ].map { simd_normalize($0) }

        for k in 0..<base.count {
            let d = 1 + (rng.next() - 0.5) * 2 * roughness
            base[k] *= radius * d
        }

        let faces: [[Int]] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
        ]

        var pos = [SIMD3<Float>]()
        var col = [SIMD3<Float>]()
        for f in faces {
            let shade = 0.86 + rng.next() * 0.28
            for idx in f {
                pos.append(base[idx])
                col.append(simd_clamp(color * shade, SIMD3(repeating: 0), SIMD3(repeating: 1)))
            }
        }
        return flatShaded(positions: pos, colors: col, material: material)
    }

    static func material(_ color: UIColor, metal: Bool = false, roughness: CGFloat = 0.6,
                         emission: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = metal ? .physicallyBased : .lambert
        m.diffuse.contents = color
        if metal {
            // Just enough sheen to catch the light — full metalness mirrors the
            // sky and blows the vehicles out to white.
            m.metalness.contents = 0.18
            m.roughness.contents = roughness
        }
        if let e = emission {
            m.emission.contents = e
            m.lightingModel = .constant
            m.diffuse.contents = color
        }
        m.locksAmbientWithDiffuse = true
        return m
    }
}

extension SCNNode {
    static func box(_ w: Float, _ h: Float, _ l: Float, chamfer: CGFloat = 0.06,
                    _ material: SCNMaterial) -> SCNNode {
        let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l), chamferRadius: chamfer)
        g.materials = [material]
        return SCNNode(geometry: g)
    }

    static func cyl(radius: Float, height: Float, _ material: SCNMaterial, segments: Int = 12) -> SCNNode {
        let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        g.radialSegmentCount = segments
        g.materials = [material]
        return SCNNode(geometry: g)
    }

    static func cone(top: Float, bottom: Float, height: Float, _ material: SCNMaterial, segments: Int = 9) -> SCNNode {
        let g = SCNCone(topRadius: CGFloat(top), bottomRadius: CGFloat(bottom), height: CGFloat(height))
        g.radialSegmentCount = segments
        g.materials = [material]
        return SCNNode(geometry: g)
    }

    static func sphere(_ r: Float, _ material: SCNMaterial, segments: Int = 12) -> SCNNode {
        let g = SCNSphere(radius: CGFloat(r))
        g.segmentCount = segments
        g.materials = [material]
        return SCNNode(geometry: g)
    }

    func positioned(_ x: Float, _ y: Float, _ z: Float) -> SCNNode {
        position = SCNVector3(x, y, z)
        return self
    }

    func rotated(x: Float = 0, y: Float = 0, z: Float = 0) -> SCNNode {
        eulerAngles = SCNVector3(x, y, z)
        return self
    }

    func scaled(_ s: Float) -> SCNNode {
        scale = SCNVector3(s, s, s)
        return self
    }
}
