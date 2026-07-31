import SceneKit
import simd

/// Endless world made of square chunks generated around the player and
/// quietly recycled once they fall behind the fog.
final class TerrainSystem {

    let root = SCNNode()

    private var chunks: [SIMD2<Int32>: SCNNode] = [:]
    private var chunkColliders: [SIMD2<Int32>: [Collider]] = [:]
    private var queue: [SIMD2<Int32>] = []
    private var prototypes: [PropKind: [SCNNode]] = [:]

    private let biome: Biome
    private let chunkSize: Float = 80
    private let resolution = 14
    private let radius: Int32 = 3
    private let maxBuildsPerFrame = 2

    init(biome: Biome) {
        self.biome = biome
        var seed: UInt64 = UInt64(biome.kind.rawValue &* 7919 &+ 17)
        for kind in Set(biome.props) {
            var variants: [SCNNode] = []
            for i in 0..<3 {
                variants.append(PropFactory.prototype(kind, seed: seed &+ UInt64(i * 977)))
            }
            prototypes[kind] = variants
            seed &+= 6151
        }
    }

    // MARK: - Streaming

    func update(around p: SIMD3<Float>) {
        let cx = Int32(floor(p.x / chunkSize))
        let cz = Int32(floor(p.z / chunkSize))

        var wanted = Set<SIMD2<Int32>>()
        for dz in -radius...radius {
            for dx in -radius...radius {
                // trim the corners — a circle of chunks reads better through fog
                if dx * dx + dz * dz > (radius * radius) + radius { continue }
                wanted.insert(SIMD2(cx + dx, cz + dz))
            }
        }

        for key in chunks.keys where !wanted.contains(key) {
            chunks[key]?.removeFromParentNode()
            chunks.removeValue(forKey: key)
            chunkColliders.removeValue(forKey: key)
        }

        queue = wanted.filter { chunks[$0] == nil }
            .sorted { a, b in
                let da = (a &- SIMD2(cx, cz)), db = (b &- SIMD2(cx, cz))
                return (da.x * da.x + da.y * da.y) < (db.x * db.x + db.y * db.y)
            }

        var built = 0
        while built < maxBuildsPerFrame, let key = queue.first {
            queue.removeFirst()
            let node = buildChunk(key)
            chunks[key] = node
            root.addChildNode(node)
            built += 1
        }
    }

    func removeAll() {
        for (_, n) in chunks { n.removeFromParentNode() }
        chunks.removeAll()
        chunkColliders.removeAll()
        queue.removeAll()
    }

    /// Scenery close enough to bump into, from the chunk under `p` and its neighbours.
    func colliders(near p: SIMD2<Float>) -> [Collider] {
        let cx = Int32(floor(p.x / chunkSize))
        let cz = Int32(floor(p.y / chunkSize))
        var result: [Collider] = []
        for dz in Int32(-1)...1 {
            for dx in Int32(-1)...1 {
                if let list = chunkColliders[SIMD2(cx + dx, cz + dz)] {
                    for c in list where simd_distance_squared(c.position, p) < 400 {
                        result.append(c)
                    }
                }
            }
        }
        return result
    }

    /// How wide each kind of scenery is at the base. Zero means you drive straight through.
    private static func collisionRadius(_ kind: PropKind) -> Float {
        switch kind {
        case .pineTree, .snowPine:  return 0.55
        case .roundTree:            return 0.6
        case .palm, .islandPalm:    return 0.42
        case .cactus:               return 0.5
        case .rock, .iceRock:       return 0.85
        case .moonRock:             return 1.25
        case .asteroid:             return 2.6
        case .satellite:            return 2.4
        case .crystal:              return 0.55
        case .deadWood:             return 0.3
        case .buoy:                 return 0.5
        case .bush, .shell, .dune:  return 0
        }
    }

    /// Fill in the chunks nearest the player immediately, so a new world is never empty.
    func prime(around p: SIMD3<Float>) {
        for _ in 0..<40 { update(around: p) }
    }

    // MARK: - Building

    private func buildChunk(_ key: SIMD2<Int32>) -> SCNNode {
        let node = SCNNode()
        let ox = Float(key.x) * chunkSize
        let oz = Float(key.y) * chunkSize
        node.position = SCNVector3(ox, 0, oz)

        if biome.hasTerrain {
            node.addChildNode(buildGround(originX: ox, originZ: oz))
        }
        chunkColliders[key] = scatterProps(into: node, originX: ox, originZ: oz, key: key)
        return node
    }

    private func buildGround(originX ox: Float, originZ oz: Float) -> SCNNode {
        let n = resolution
        let step = chunkSize / Float(n)

        var heights = [Float](repeating: 0, count: (n + 1) * (n + 1))
        for j in 0...n {
            for i in 0...n {
                let wx = ox + Float(i) * step
                let wz = oz + Float(j) * step
                heights[j * (n + 1) + i] = biome.height(SIMD2(wx, wz))
            }
        }

        var positions = [SIMD3<Float>]()
        var colors = [SIMD3<Float>]()
        positions.reserveCapacity(n * n * 6)
        colors.reserveCapacity(n * n * 6)

        for j in 0..<n {
            for i in 0..<n {
                let x0 = Float(i) * step, x1 = Float(i + 1) * step
                let z0 = Float(j) * step, z1 = Float(j + 1) * step
                let h00 = heights[j * (n + 1) + i]
                let h10 = heights[j * (n + 1) + i + 1]
                let h01 = heights[(j + 1) * (n + 1) + i]
                let h11 = heights[(j + 1) * (n + 1) + i + 1]

                let a = SIMD3(x0, h00, z0)
                let b = SIMD3(x1, h10, z0)
                let c = SIMD3(x0, h01, z1)
                let d = SIMD3(x1, h11, z1)

                appendTriangle(a, c, b, &positions, &colors, ox: ox, oz: oz)
                appendTriangle(b, c, d, &positions, &colors, ox: ox, oz: oz)
            }
        }

        let geo = GeometryKit.flatShaded(positions: positions, colors: colors)
        let node = SCNNode(geometry: geo)
        node.castsShadow = false
        return node
    }

    private func appendTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
                                _ positions: inout [SIMD3<Float>], _ colors: inout [SIMD3<Float>],
                                ox: Float, oz: Float) {
        positions.append(a); positions.append(b); positions.append(c)
        var normal = simd_cross(b - a, c - a)
        let len = simd_length(normal)
        normal = len > 1e-6 ? normal / len : SIMD3(0, 1, 0)
        let slope = 1 - abs(normal.y)
        let mid = (a + b + c) / 3
        let jitter = Noise.value(SIMD2(mid.x + ox, mid.z + oz) * 0.21)
        let color = biome.groundColor(height: mid.y, slope: slope, jitter: jitter)
        colors.append(color); colors.append(color); colors.append(color)
    }

    @discardableResult
    private func scatterProps(into node: SCNNode, originX ox: Float, originZ oz: Float,
                              key: SIMD2<Int32>) -> [Collider] {
        var colliders: [Collider] = []
        guard !biome.props.isEmpty else { return colliders }
        var rng = SeededRandom(UInt64(bitPattern: Int64(key.x) &* 73_856_093 ^ Int64(key.y) &* 19_349_663)
                               &+ UInt64(biome.kind.rawValue &+ 1) &* 83_492_791)

        let count = Int(Float(biome.propDensity) * 1.55)
        for _ in 0..<count {
            let kind = biome.props[Int(rng.next() * Float(biome.props.count - 1) + 0.5)]
            let lx = rng.next() * chunkSize
            let lz = rng.next() * chunkSize
            let wx = ox + lx, wz = oz + lz

            var y: Float
            if biome.hasTerrain {
                let h = biome.height(SIMD2(wx, wz))
                if let level = biome.waterLevel {
                    if kind == .buoy {
                        if h > level - 2.5 { continue }
                        y = level
                    } else if kind == .shell {
                        if h < level + 0.05 || h > level + 1.2 { continue }
                        y = h
                    } else {
                        if h < level + 0.7 { continue }
                        y = h
                    }
                } else {
                    y = h
                }
                // keep the steepest faces clear so nothing looks glued to a cliff
                let s = abs(biome.height(SIMD2(wx + 2, wz)) - biome.height(SIMD2(wx - 2, wz))) / 4
                if s > 0.75 && rng.chance(0.8) { continue }
            } else {
                let side: Float = rng.chance(0.5) ? 1 : -1
                y = side * rng.range(9, 46)
            }

            guard let variants = prototypes[kind], !variants.isEmpty else { continue }
            let proto = variants[Int(rng.next() * Float(variants.count - 1) + 0.5)]
            let clone = proto.clone()
            clone.position = SCNVector3(lx, y, lz)
            clone.eulerAngles = SCNVector3(0, rng.range(0, 2 * .pi), 0)
            let s = rng.range(0.75, 1.35)
            clone.scale = SCNVector3(s, s * rng.range(0.9, 1.15), s)
            clone.castsShadow = biome.hasTerrain
            node.addChildNode(clone)

            let r = TerrainSystem.collisionRadius(kind) * s
            if r > 0 { colliders.append(Collider(position: SIMD2(wx, wz), radius: r)) }
        }
        return colliders
    }
}
