import SceneKit
import simd

/// Builds one prototype node per prop kind. Chunks then clone the prototypes,
/// so the whole world shares a handful of geometries.
enum PropFactory {

    /// A palm frond built as real geometry: a tapered blade that droops toward the
    /// tip. Node scaling doesn't survive `flattenedClone`, so the shape is baked in.
    private static func frondGeometry(length: Float, width: Float, droop: Float,
                                      color: SIMD3<Float>) -> SCNGeometry {
        let segs = 7
        var pos = [SIMD3<Float>]()
        var col = [SIMD3<Float>]()

        func spine(_ t: Float) -> (SIMD3<Float>, Float) {
            let centre = SIMD3(length * t, -droop * length * t * t, 0)
            let halfWidth = width * sin(Float.pi * powf(t, 0.55)) * 0.5 + 0.015
            return (centre, halfWidth)
        }

        for i in 0..<segs {
            let t0 = Float(i) / Float(segs), t1 = Float(i + 1) / Float(segs)
            let (c0, w0) = spine(t0)
            let (c1, w1) = spine(t1)
            let a = c0 + SIMD3(0, 0, w0), b = c0 - SIMD3(0, 0, w0)
            let c = c1 + SIMD3(0, 0, w1), d = c1 - SIMD3(0, 0, w1)
            let tint = simd_clamp(color * (0.88 + 0.22 * (1 - t0)),
                                  SIMD3(repeating: 0), SIMD3(repeating: 1))
            pos.append(a); pos.append(b); pos.append(c)
            pos.append(b); pos.append(d); pos.append(c)
            for _ in 0..<6 { col.append(tint) }
        }
        return GeometryKit.flatShaded(positions: pos, colors: col,
                                      material: GeometryKit.foliageVertexMaterial)
    }


    static func prototype(_ kind: PropKind, seed: UInt64) -> SCNNode {
        let node: SCNNode
        switch kind {
        case .pineTree:   node = pine(seed: seed, snowy: false)
        case .snowPine:   node = pine(seed: seed, snowy: true)
        case .roundTree:  node = roundTree(seed: seed)
        case .bush:       node = bush(seed: seed)
        case .rock:       node = rock(seed: seed, color: vec(0x8A8377), scale: 1)
        case .iceRock:    node = rock(seed: seed, color: vec(0xC4D8E6), scale: 1.1)
        case .moonRock:   node = rock(seed: seed, color: vec(0x8E8E96), scale: 1.4)
        case .asteroid:   node = asteroid(seed: seed)
        case .cactus:     node = cactus(seed: seed)
        case .palm:       node = palm(seed: seed, tall: true)
        case .islandPalm: node = palm(seed: seed, tall: false)
        case .deadWood:   node = deadWood(seed: seed)
        case .crystal:    node = crystal(seed: seed)
        case .satellite:  node = satellite()
        case .buoy:       node = buoy()
        case .shell:      node = shell(seed: seed)
        case .dune:       node = duneMound(seed: seed)
        }
        return node.flattenedClone()
    }

    // MARK: - Forest / snow

    private static func pine(seed: UInt64, snowy: Bool) -> SCNNode {
        var rng = SeededRandom(seed)
        let root = SCNNode()
        let barkColor = snowy ? rgb(0x5A4E45) : rgb(0x6B5240)
        let bark = GeometryKit.material(barkColor)
        let leafColor = snowy ? rgb(0x3E6353) : rgb(0x3C6B41)
        let leaf = GeometryKit.material(leafColor)
        let snow = GeometryKit.material(rgb(0xF2F7FC))

        let h = rng.range(1.6, 2.6)
        let trunk = SCNNode.cyl(radius: rng.range(0.16, 0.24), height: h, bark, segments: 7)
        trunk.position = SCNVector3(0, h / 2, 0)
        root.addChildNode(trunk)

        let tiers = Int(rng.range(3, 4.99))
        var y = h * 0.75
        var r = rng.range(1.5, 2.1)
        for i in 0..<tiers {
            let ch = r * rng.range(1.25, 1.55)
            let cone = SCNNode.cone(top: 0, bottom: r, height: ch, leaf, segments: 8)
            cone.position = SCNVector3(0, y + ch / 2, 0)
            root.addChildNode(cone)
            if snowy {
                let cap = SCNNode.cone(top: 0, bottom: r * 0.86, height: ch * 0.42, snow, segments: 8)
                cap.position = SCNVector3(0, y + ch * 0.82, 0)
                root.addChildNode(cap)
            }
            y += ch * 0.52
            r *= rng.range(0.66, 0.78)
            _ = i
        }
        return root
    }

    private static func roundTree(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 7)
        let root = SCNNode()
        let bark = GeometryKit.material(rgb(0x7A5C42))
        let h = rng.range(1.8, 3.0)
        let trunk = SCNNode.cyl(radius: rng.range(0.18, 0.3), height: h, bark, segments: 7)
        trunk.position = SCNVector3(0, h / 2, 0)
        root.addChildNode(trunk)

        let greens: [SIMD3<Float>] = [vec(0x5B8C4A), vec(0x6F9E52), vec(0x4E7D46), vec(0x7FAA5C)]
        let blobs = Int(rng.range(2, 3.99))
        for _ in 0..<blobs {
            let r = rng.range(0.95, 1.6)
            let g = GeometryKit.blob(radius: r, roughness: 0.22,
                                     color: greens[Int(rng.next() * 3.99)], seed: UInt64(rng.next() * 90000))
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(rng.range(-0.55, 0.55), h + rng.range(0.2, 1.0), rng.range(-0.55, 0.55))
            root.addChildNode(n)
        }
        return root
    }

    private static func bush(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 31)
        let root = SCNNode()
        for _ in 0..<Int(rng.range(2, 3.99)) {
            let r = rng.range(0.35, 0.7)
            let g = GeometryKit.blob(radius: r, roughness: 0.3, color: vec(0x5F8A4C), seed: UInt64(rng.next() * 90000))
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(rng.range(-0.4, 0.4), r * 0.7, rng.range(-0.4, 0.4))
            root.addChildNode(n)
        }
        return root
    }

    // MARK: - Rocks

    private static func rock(seed: UInt64, color: SIMD3<Float>, scale: Float) -> SCNNode {
        var rng = SeededRandom(seed &+ 101)
        let r = rng.range(0.5, 1.5) * scale
        let g = GeometryKit.blob(radius: r, roughness: 0.34, color: color, seed: seed &+ 5)
        let n = SCNNode(geometry: g)
        n.scale = SCNVector3(1, rng.range(0.55, 0.9), 1)
        n.position = SCNVector3(0, r * 0.35, 0)
        n.eulerAngles = SCNVector3(0, rng.range(0, 6.28), 0)
        return n
    }

    private static func asteroid(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 555)
        let r = rng.range(1.2, 4.2)
        let colors: [SIMD3<Float>] = [vec(0x6A6472), vec(0x7C6A5E), vec(0x5A5668)]
        let g = GeometryKit.blob(radius: r, roughness: 0.42,
                                 color: colors[Int(rng.next() * 2.99)], seed: seed &+ 9)
        let n = SCNNode(geometry: g)
        n.scale = SCNVector3(rng.range(0.7, 1.2), rng.range(0.6, 1.1), rng.range(0.7, 1.2))
        // slow tumble
        let spin = SCNAction.rotateBy(x: CGFloat(rng.range(-0.4, 0.4)),
                                      y: CGFloat(rng.range(-0.5, 0.5)),
                                      z: CGFloat(rng.range(-0.3, 0.3)),
                                      duration: Double(rng.range(14, 34)))
        n.runAction(.repeatForever(spin))
        return n
    }

    // MARK: - Desert

    private static func cactus(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 202)
        let root = SCNNode()
        let mat = GeometryKit.material(rgb(0x5C8A57))
        let h = rng.range(1.8, 3.4)
        let r = rng.range(0.22, 0.34)
        let body = SCNNode.cyl(radius: r, height: h, mat, segments: 9)
        body.position = SCNVector3(0, h / 2, 0)
        root.addChildNode(body)
        let cap = SCNNode.sphere(r, mat, segments: 9)
        cap.position = SCNVector3(0, h, 0)
        root.addChildNode(cap)

        for side in [Float(-1), 1] {
            if !rng.chance(0.6) { continue }
            let ah = rng.range(0.6, 1.1)
            let arm = SCNNode.cyl(radius: r * 0.75, height: ah, mat, segments: 8)
            let ay = rng.range(h * 0.4, h * 0.7)
            arm.position = SCNVector3(side * (r + ah / 2 - 0.05), ay, 0)
            arm.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            root.addChildNode(arm)
            let up = SCNNode.cyl(radius: r * 0.7, height: ah * 1.2, mat, segments: 8)
            up.position = SCNVector3(side * (r + ah - 0.05), ay + ah * 0.6, 0)
            root.addChildNode(up)
            let ucap = SCNNode.sphere(r * 0.7, mat, segments: 8)
            ucap.position = SCNVector3(side * (r + ah - 0.05), ay + ah * 1.2, 0)
            root.addChildNode(ucap)
        }
        return root
    }

    private static func duneMound(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 313)
        let r = rng.range(2.5, 5.0)
        let g = GeometryKit.blob(radius: r, roughness: 0.14, color: vec(0xDCBB88), seed: seed &+ 3)
        let n = SCNNode(geometry: g)
        n.scale = SCNVector3(1.4, rng.range(0.16, 0.28), 1.0)
        n.position = SCNVector3(0, -r * 0.05, 0)
        n.eulerAngles = SCNVector3(0, rng.range(0, 6.28), 0)
        return n
    }

    private static func deadWood(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 404)
        let root = SCNNode()
        let mat = GeometryKit.material(rgb(0x8B7358))
        let h = rng.range(1.0, 2.0)
        let trunk = SCNNode.cyl(radius: rng.range(0.1, 0.18), height: h, mat, segments: 6)
        trunk.position = SCNVector3(0, h * 0.4, 0)
        trunk.eulerAngles = SCNVector3(rng.range(-0.4, 0.4), 0, rng.range(-0.5, 0.5))
        root.addChildNode(trunk)
        if rng.chance(0.6) {
            let b = SCNNode.cyl(radius: 0.08, height: h * 0.6, mat, segments: 5)
            b.position = SCNVector3(rng.range(-0.3, 0.3), h * 0.6, 0)
            b.eulerAngles = SCNVector3(0, 0, rng.range(0.6, 1.2))
            root.addChildNode(b)
        }
        return root
    }

    // MARK: - Shore

    private static func palm(seed: UInt64, tall: Bool) -> SCNNode {
        var rng = SeededRandom(seed &+ 606)
        let root = SCNNode()
        let bark = GeometryKit.material(rgb(0x9A7B58))

        let segments = tall ? Int(rng.range(4, 6.49)) : Int(rng.range(3, 4.99))
        let lean = rng.range(-0.12, 0.12)
        var y: Float = 0
        var x: Float = 0
        let segH = rng.range(0.62, 0.82)
        for i in 0..<segments {
            let r = 0.26 - Float(i) * 0.014
            let s = SCNNode.cyl(radius: max(r, 0.1), height: segH, bark, segments: 7)
            x += lean * Float(i) * 0.06
            s.position = SCNVector3(x, y + segH / 2, 0)
            s.eulerAngles = SCNVector3(0, 0, -lean * Float(i) * 0.16)
            root.addChildNode(s)
            y += segH * 0.96
        }

        // Fronds radiate outward from the crown and droop at the tips.
        let count = Int(rng.range(7, 9.99))
        for i in 0..<count {
            let a = Float(i) / Float(count) * 2 * .pi + rng.range(-0.12, 0.12)
            let len = rng.range(2.9, 3.8)

            // Flat hierarchy on purpose: `flattenedClone()` keeps direct children
            // only, so a frond nested under a holder node would vanish. Euler order
            // is roll-then-yaw, which gives exactly the holder ∘ leaf transform.
            let leaf = SCNNode(geometry: frondGeometry(length: len,
                                                       width: rng.range(0.52, 0.78),
                                                       droop: rng.range(0.20, 0.40),
                                                       color: vec(0x4F8B4A)))
            leaf.position = SCNVector3(x, y, 0)
            leaf.eulerAngles = SCNVector3(0, a, rng.range(0.02, 0.20))
            root.addChildNode(leaf)
        }

        if rng.chance(0.5) {
            let coco = GeometryKit.material(rgb(0x6B4F35))
            for _ in 0..<2 {
                let c = SCNNode.sphere(0.14, coco, segments: 7)
                c.position = SCNVector3(x + rng.range(-0.2, 0.2), y - 0.1, rng.range(-0.2, 0.2))
                root.addChildNode(c)
            }
        }
        return root
    }

    private static func shell(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 707)
        let colors: [SIMD3<Float>] = [vec(0xF0E0D0), vec(0xEBC8B8), vec(0xE8D8B0)]
        let g = GeometryKit.blob(radius: rng.range(0.14, 0.26), roughness: 0.25,
                                 color: colors[Int(rng.next() * 2.99)], seed: seed)
        let n = SCNNode(geometry: g)
        n.scale = SCNVector3(1.3, 0.45, 1)
        n.position = SCNVector3(0, 0.05, 0)
        return n
    }

    private static func buoy() -> SCNNode {
        let root = SCNNode()
        let body = SCNNode.cone(top: 0.18, bottom: 0.42, height: 1.1,
                                GeometryKit.material(rgb(0xE8663F)), segments: 9)
        body.position = SCNVector3(0, 0.35, 0)
        root.addChildNode(body)
        let lamp = SCNNode.sphere(0.16, GeometryKit.material(rgb(0xFFD98A), emission: rgb(0xFFCB6A)), segments: 8)
        lamp.position = SCNVector3(0, 1.05, 0)
        root.addChildNode(lamp)
        let bob = SCNAction.sequence([
            .moveBy(x: 0, y: 0.22, z: 0, duration: 1.9),
            .moveBy(x: 0, y: -0.22, z: 0, duration: 1.9),
        ])
        bob.timingMode = .easeInEaseOut
        root.runAction(.repeatForever(bob))
        return root
    }

    // MARK: - Moon / space

    private static func crystal(seed: UInt64) -> SCNNode {
        var rng = SeededRandom(seed &+ 808)
        let root = SCNNode()
        let tints = [rgb(0x8FD8E8), rgb(0xB9A6F0), rgb(0x86E8C0)]
        let tint = tints[Int(rng.next() * 2.99)]
        for _ in 0..<Int(rng.range(2, 3.99)) {
            let h = rng.range(1.0, 2.4)
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.diffuse.contents = tint
            m.emission.contents = tint.withAlphaComponent(0.55)
            m.transparency = 0.85
            let c = SCNNode.cone(top: 0.02, bottom: rng.range(0.16, 0.3), height: h, m, segments: 5)
            c.position = SCNVector3(rng.range(-0.4, 0.4), h / 2, rng.range(-0.4, 0.4))
            c.eulerAngles = SCNVector3(rng.range(-0.2, 0.2), rng.range(0, 6.28), rng.range(-0.2, 0.2))
            root.addChildNode(c)
        }
        return root
    }

    private static func satellite() -> SCNNode {
        let root = SCNNode()
        let hull = GeometryKit.material(rgb(0xD8D8E0), metal: true, roughness: 0.35)
        let panel = GeometryKit.material(rgb(0x2E4C86), metal: true, roughness: 0.2)
        let body = SCNNode.box(1.2, 1.2, 1.8, chamfer: 0.1, hull)
        root.addChildNode(body)
        for s in [Float(-1), 1] {
            let p = SCNNode.box(2.6, 0.06, 1.2, chamfer: 0.02, panel)
            p.position = SCNVector3(s * 1.95, 0, 0)
            root.addChildNode(p)
        }
        let dish = SCNNode.cone(top: 0.7, bottom: 0.05, height: 0.5, hull, segments: 12)
        dish.position = SCNVector3(0, 0.9, 0)
        root.addChildNode(dish)
        root.runAction(.repeatForever(.rotateBy(x: 0.2, y: 0.6, z: 0, duration: 26)))
        return root
    }
}
