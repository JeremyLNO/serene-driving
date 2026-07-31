import SceneKit
import simd

/// Speed mode only: cut gems that drift into view and are collected by driving
/// through them. They never block you and there is nothing to lose — the counter
/// starts from zero every time the app is launched.
final class DiamondField {

    let root = SCNNode()

    private struct Gem {
        var node: SCNNode
        var position: SIMD2<Float>
    }

    private var gems: [Gem] = []
    private var rng = SeededRandom(51_217)
    private var biome: Biome

    private let target = 20
    private let spawnNear: Float = 60
    private let spawnFar: Float = 145
    private let despawn: Float = 240
    private let collectRadius: Float = 4.6

    /// Off in Serene mode — the field empties itself when it goes quiet.
    var isActive = false {
        didSet { if !isActive { clear() } }
    }

    init(biome: Biome) { self.biome = biome }

    func reset(biome: Biome) {
        self.biome = biome
        clear()
    }

    func clear() {
        for g in gems { g.node.removeFromParentNode() }
        gems.removeAll()
    }

    /// - Returns: how many gems were collected this frame.
    func update(around p: SIMD3<Float>, heading: Float, time: Float) -> Int {
        guard isActive else { return 0 }
        let here = SIMD2(p.x, p.z)

        // Drop the ones we've left far behind.
        gems.removeAll { gem in
            if simd_distance(gem.position, here) > despawn {
                gem.node.removeFromParentNode()
                return true
            }
            return false
        }

        var collected = 0
        gems.removeAll { gem in
            guard simd_distance(gem.position, here) < collectRadius else { return false }
            collected += 1
            collect(gem.node)
            return true
        }

        while gems.count < target { spawnTrail(around: here, heading: heading) }
        return collected
    }

    // MARK: - Spawning

    /// Gems come in short curving trails rather than scattered singles — you
    /// sweep through a whole run of them, which is what makes it satisfying.
    private func spawnTrail(around here: SIMD2<Float>, heading: Float) {
        let forward = SIMD2(-sin(heading), -cos(heading))
        let spread = rng.range(-0.7, 0.7)
        let dir = SIMD2(forward.x * cos(spread) - forward.y * sin(spread),
                        forward.x * sin(spread) + forward.y * cos(spread))
        let anchor = here + dir * rng.range(spawnNear, spawnFar)

        // The trail runs roughly away from us, bending gently to one side.
        let side = SIMD2(-dir.y, dir.x)
        let bend = rng.range(-0.55, 0.55)
        let count = Int(rng.range(4, 6.99))
        let spacing = rng.range(7, 10)

        for i in 0..<count {
            let t = Float(i)
            let spot = anchor + dir * (t * spacing) + side * (bend * t * t * 0.9)
            var y: Float
            if biome.hasTerrain {
                y = biome.height(spot)
                if let level = biome.waterLevel { y = max(y, level) }
                y += 1.5
            } else {
                y = rng.range(-3, 3)       // deep space: in the flight corridor
            }

            let node = DiamondField.makeDiamond(seed: UInt64(rng.next() * 900_000))
            node.position = SCNVector3(spot.x, y, spot.y)
            root.addChildNode(node)
            gems.append(Gem(node: node, position: spot))
        }
    }

    private func collect(_ node: SCNNode) {
        node.runAction(.sequence([
            .group([
                .scale(to: 2.4, duration: 0.30),
                .fadeOut(duration: 0.30),
            ]),
            .removeFromParentNode(),
        ]))
    }

    // MARK: - The gem itself

    private static let gemMaterial: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = UIColor.white          // hue comes from vertex colours
        m.emission.contents = UIColor(white: 0.30, alpha: 1)
        m.locksAmbientWithDiffuse = true
        return m
    }()

    private static let glowMaterial: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = SkyFactory.softDot
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }()

    static func makeDiamond(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed)
        let tints: [SIMD3<Float>] = [vec(0x8FE8F0), vec(0xA8D8FF), vec(0xBFF0DC), vec(0xD8C4FF)]
        let tint = tints[Int(rng.next() * 3.99)]

        // A cut gem: a crown of facets above a girdle, and a point below.
        let girdle: Float = 0.42
        let crown: Float = 0.34
        let pavilion: Float = 0.62
        let sides = 6

        var pos = [SIMD3<Float>]()
        var col = [SIMD3<Float>]()
        let top = SIMD3<Float>(0, crown, 0)
        let bottom = SIMD3<Float>(0, -pavilion, 0)

        for i in 0..<sides {
            let a0 = Float(i) / Float(sides) * 2 * .pi
            let a1 = Float(i + 1) / Float(sides) * 2 * .pi
            let r0 = SIMD3(cos(a0) * girdle, 0, sin(a0) * girdle)
            let r1 = SIMD3(cos(a1) * girdle, 0, sin(a1) * girdle)

            // Each facet catches the light differently — that's the sparkle.
            let crownShade = 0.75 + Float(i % 3) * 0.22 + rng.range(0, 0.10)
            let pavShade = 0.55 + Float((i + 1) % 3) * 0.20 + rng.range(0, 0.10)

            pos.append(top); pos.append(r0); pos.append(r1)
            let c1 = simd_clamp(tint * crownShade, SIMD3(repeating: 0), SIMD3(repeating: 1))
            for _ in 0..<3 { col.append(c1) }

            pos.append(bottom); pos.append(r1); pos.append(r0)
            let c2 = simd_clamp(tint * pavShade, SIMD3(repeating: 0), SIMD3(repeating: 1))
            for _ in 0..<3 { col.append(c2) }
        }

        let geo = GeometryKit.flatShaded(positions: pos, colors: col, material: gemMaterial)
        let gem = SCNNode(geometry: geo)
        gem.castsShadow = false

        let node = SCNNode()
        node.addChildNode(gem)

        // A soft halo that always faces the camera, so they read from far away.
        let halo = SCNNode(geometry: SCNPlane(width: 2.6, height: 2.6))
        halo.geometry?.materials = [glowMaterial]
        halo.opacity = 0.55
        halo.castsShadow = false
        halo.renderingOrder = 12
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        halo.constraints = [billboard]
        node.addChildNode(halo)

        node.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.5)))
        let bob = SCNAction.sequence([
            .moveBy(x: 0, y: 0.32, z: 0, duration: 1.4),
            .moveBy(x: 0, y: -0.32, z: 0, duration: 1.4),
        ])
        bob.timingMode = .easeInEaseOut
        gem.runAction(.repeatForever(bob))
        return node
    }
}
