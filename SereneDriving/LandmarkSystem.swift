import SceneKit
import simd

/// Somewhere out in the haze there is one thing worth steering toward. You never
/// have to. Nothing counts it, nothing times it — reaching it just gives you a
/// small moment and its name.
final class LandmarkSystem {

    let root = SCNNode()

    private(set) var name: String = ""
    private(set) var position: SIMD2<Float>?
    private(set) var collider: Collider?
    private var reached = false
    private var node: SCNNode?
    private var biome: Biome

    init(biome: Biome) { self.biome = biome }

    func place(biome: Biome, near origin: SIMD3<Float>, rng: inout SeededRandom) {
        self.biome = biome
        root.childNodes.forEach { $0.removeFromParentNode() }
        reached = false
        node = nil
        position = nil
        collider = nil

        let built = LandmarkFactory.make(for: biome.kind, rng: &rng)
        name = built.name

        // Close enough to be a silhouette in the fog, far enough to be a journey.
        let bearing = rng.range(0, 2 * .pi)
        let direction = SIMD2(-sin(bearing), -cos(bearing))
        var spot = SIMD2(origin.x, origin.z) + direction * rng.range(165, 215)

        var y: Float = 0
        if biome.hasTerrain {
            // A lighthouse that isn't on its own island needs dry ground under it.
            if let level = biome.waterLevel, !built.floatsOnWater {
                var tries = 0
                while biome.height(spot) < level + 1.0 && tries < 40 {
                    spot += direction * 14
                    tries += 1
                }
            }
            y = biome.height(spot)
            if let level = biome.waterLevel, built.floatsOnWater { y = level - 0.4 }
        }

        built.node.position = SCNVector3(spot.x, y, spot.y)
        built.node.eulerAngles = SCNVector3(0, rng.range(0, 2 * .pi), 0)
        root.addChildNode(built.node)

        node = built.node
        position = spot
        // Radius zero means you're meant to pass straight through it.
        collider = built.radius > 0 ? Collider(position: spot, radius: built.radius) : nil
    }

    /// Returns the landmark's name the first time you get close to it.
    func update(playerAt p: SIMD3<Float>) -> String? {
        guard !reached, let spot = position, let node else { return nil }
        guard simd_distance(SIMD2(p.x, p.z), spot) < 26 else { return nil }
        reached = true

        // The moment: a soft bloom of light around the base.
        let burst = SCNParticleSystem()
        burst.particleImage = SkyFactory.softDot
        burst.emitterShape = SCNSphere(radius: 5)
        burst.birthLocation = .volume
        burst.birthRate = 260
        burst.emissionDuration = 2.4
        burst.loops = false
        burst.particleLifeSpan = 5
        burst.particleLifeSpanVariation = 2
        burst.particleSize = 0.32
        burst.particleSizeVariation = 0.2
        burst.particleColor = LandmarkFactory.sparkTint(for: biome.kind)
        burst.particleVelocity = 2.2
        burst.particleVelocityVariation = 1.6
        burst.emittingDirection = SCNVector3(0, 1, 0)
        burst.spreadingAngle = 180
        burst.acceleration = SCNVector3(0, 0.8, 0)
        burst.isAffectedByGravity = false
        burst.blendMode = .additive
        burst.isLightingEnabled = false

        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 0.9, 0.0]
        fade.keyTimes = [0.0, 0.2, 1.0]
        fade.duration = 1
        burst.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]

        let emitter = SCNNode()
        emitter.position = SCNVector3(0, 3, 0)
        emitter.addParticleSystem(burst)
        node.addChildNode(emitter)
        emitter.runAction(.sequence([.wait(duration: 9), .removeFromParentNode()]))

        return name
    }
}

// MARK: - The landmarks themselves

enum LandmarkFactory {

    struct Built {
        var node: SCNNode
        var name: String
        var radius: Float
        var floatsOnWater: Bool = false
    }

    static func sparkTint(for kind: Biome.Kind) -> UIColor {
        switch kind {
        case .forest:  return rgb(0xFFE9A8)
        case .snow:    return rgb(0xDCEEFF)
        case .desert:  return rgb(0xFFD9A0)
        case .beach,
             .ocean:   return rgb(0xC8F2FF)
        case .moon:    return rgb(0xBFD8FF)
        case .space:   return rgb(0xD6C8FF)
        case .autumn:  return rgb(0xFFD9A0)
        case .canyon:  return rgb(0xFFC48A)
        case .saltflats: return rgb(0xEAF4FF)
        case .volcano: return rgb(0xFF9A55)
        case .alien:   return rgb(0x8FF0D8)
        }
    }

    static func make(for kind: Biome.Kind, rng: inout SeededRandom) -> Built {
        switch kind {
        case .forest:  return greatTree(&rng)
        case .snow:    return iceArch(&rng)
        case .desert:  return rockArch(&rng)
        case .beach:   return lighthouse(&rng, name: "The Old Light")
        case .ocean:   return lighthouse(&rng, name: "The Lonely Light", island: true)
        case .moon:    return monolith(&rng)
        case .space:   return gate(&rng)
        case .autumn:  return greatTree(&rng, autumn: true)
        case .canyon:  return rockArch(&rng, stone: vec(0xB0603C), name: "The Wind Gate")
        case .saltflats: return monolith(&rng)
        case .volcano: return rockArch(&rng, stone: vec(0x2E2830), name: "The Black Arch")
        case .alien:   return giantMushroom(&rng)
        }
    }

    // MARK: Forest

    private static func greatTree(_ rng: inout SeededRandom, autumn: Bool = false) -> Built {
        let root = SCNNode()
        let bark = GeometryKit.material(rgb(0x6A5039))
        let height = rng.range(20, 26)

        let trunk = SCNNode.cone(top: 1.1, bottom: 2.6, height: height, bark, segments: 10)
        trunk.position = SCNVector3(0, height / 2, 0)
        root.addChildNode(trunk)

        // buttress roots
        for i in 0..<6 {
            let a = Float(i) / 6 * 2 * .pi
            let buttress = SCNNode.cone(top: 0.2, bottom: 1.1, height: 5, bark, segments: 6)
            buttress.position = SCNVector3(cos(a) * 2.2, 2.0, sin(a) * 2.2)
            buttress.eulerAngles = SCNVector3(cos(a) * 0.42, 0, -sin(a) * 0.42)
            root.addChildNode(buttress)
        }

        let greens: [SIMD3<Float>] = autumn
            ? [vec(0xC9762C), vec(0xD99B3A), vec(0xA85224)]
            : [vec(0x3E6B3F), vec(0x4E7F49), vec(0x355E38)]
        for i in 0..<9 {
            let r = rng.range(4.5, 7.5)
            let g = GeometryKit.blob(radius: r, roughness: 0.20, color: greens[i % 3],
                                     seed: UInt64(rng.next() * 90000),
                                     material: GeometryKit.solidVertexMaterial)
            let n = SCNNode(geometry: g)
            let a = Float(i) / 9 * 2 * .pi
            n.position = SCNVector3(cos(a) * rng.range(1, 5.5),
                                    height * rng.range(0.86, 1.12),
                                    sin(a) * rng.range(1, 5.5))
            root.addChildNode(n)
        }
        return Built(node: root, name: autumn ? "The Last Gold" : "The Old Oak", radius: 3.2)
    }

    // MARK: Snow

    private static func iceArch(_ rng: inout SeededRandom) -> Built {
        let root = SCNNode()
        let ice = SCNMaterial()
        ice.lightingModel = .physicallyBased
        ice.diffuse.contents = rgb(0xBFE0F0)
        ice.metalness.contents = 0.1
        ice.roughness.contents = 0.15
        ice.transparency = 0.86

        let span: Float = 13
        let height = rng.range(16, 20)
        for s in [Float(-1), 1] {
            let leg = SCNNode.cone(top: 1.1, bottom: 2.4, height: height, ice, segments: 8)
            leg.position = SCNVector3(s * span / 2, height / 2, 0)
            leg.eulerAngles = SCNVector3(0, 0, -s * 0.16)
            root.addChildNode(leg)
        }
        let segments = 9
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let a = Float.pi * t
            let block = SCNNode.box(2.0, 1.7, 2.6, chamfer: 0.5, ice)
            block.position = SCNVector3(-cos(a) * span / 2 * 0.92, height + sin(a) * 4.6, 0)
            block.eulerAngles = SCNVector3(0, 0, a - .pi / 2)
            root.addChildNode(block)
        }
        return Built(node: root, name: "The Ice Arch", radius: 8.0)
    }

    // MARK: Desert

    private static func rockArch(_ rng: inout SeededRandom,
                                stone: SIMD3<Float> = vec(0xC08D5C),
                                name: String = "The Sandstone Arch") -> Built {
        let root = SCNNode()
        let span: Float = 16
        let height = rng.range(15, 19)

        for s in [Float(-1), 1] {
            for i in 0..<4 {
                let g = GeometryKit.blob(radius: rng.range(2.4, 3.6), roughness: 0.30,
                                         color: stone, seed: UInt64(rng.next() * 90000),
                                         material: GeometryKit.solidVertexMaterial)
                let n = SCNNode(geometry: g)
                n.position = SCNVector3(s * span / 2 + rng.range(-0.8, 0.8),
                                        Float(i) * height / 4 + 2,
                                        rng.range(-0.8, 0.8))
                n.scale = SCNVector3(1, 1.25, 1)
                root.addChildNode(n)
            }
        }
        for i in 0...8 {
            let t = Float(i) / 8
            let a = Float.pi * t
            let g = GeometryKit.blob(radius: rng.range(2.2, 3.0), roughness: 0.26,
                                     color: stone, seed: UInt64(rng.next() * 90000),
                                     material: GeometryKit.solidVertexMaterial)
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(-cos(a) * span / 2, height + sin(a) * 4.2, 0)
            n.scale = SCNVector3(1.1, 0.8, 1)
            root.addChildNode(n)
        }
        return Built(node: root, name: name, radius: 9.5)
    }

    // MARK: Shore & sea

    private static func lighthouse(_ rng: inout SeededRandom, name: String, island: Bool = false) -> Built {
        let root = SCNNode()
        let white = GeometryKit.material(rgb(0xF2EEE4), metal: true, roughness: 0.55)
        let red = GeometryKit.material(rgb(0xC85F49), metal: true, roughness: 0.55)
        let dark = GeometryKit.material(rgb(0x40454C), metal: true, roughness: 0.5)

        if island {
            let g = GeometryKit.blob(radius: 11, roughness: 0.22, color: vec(0x8C7F63),
                                     seed: 8811, material: GeometryKit.solidVertexMaterial)
            let rock = SCNNode(geometry: g)
            rock.scale = SCNVector3(1.5, 0.42, 1.5)
            rock.position = SCNVector3(0, 0.6, 0)
            root.addChildNode(rock)
        }

        let height: Float = rng.range(21, 26)
        let bands = 6
        for i in 0..<bands {
            let t = Float(i) / Float(bands)
            let segH = height / Float(bands)
            let seg = SCNNode.cone(top: 2.5 - t * 1.2 - 0.28,
                                   bottom: 3.4 - t * 1.2,
                                   height: segH,
                                   i % 2 == 0 ? white : red, segments: 14)
            seg.position = SCNVector3(0, segH * (Float(i) + 0.5) + 1, 0)
            root.addChildNode(seg)
        }

        let gallery = SCNNode.cyl(radius: 2.2, height: 0.4, dark, segments: 14)
        gallery.position = SCNVector3(0, height + 1.2, 0)
        root.addChildNode(gallery)

        let lantern = SCNNode.cyl(radius: 1.5, height: 2.6,
                                  GeometryKit.material(rgb(0xFFF0C4), emission: rgb(0xF0D48A)), segments: 12)
        lantern.position = SCNVector3(0, height + 2.7, 0)
        root.addChildNode(lantern)

        let cap = SCNNode.cone(top: 0, bottom: 2.0, height: 1.8, dark, segments: 14)
        cap.position = SCNVector3(0, height + 4.9, 0)
        root.addChildNode(cap)

        // A beam that sweeps slowly around — visible from a long way off.
        let beamMat = SCNMaterial()
        beamMat.lightingModel = .constant
        beamMat.diffuse.contents = rgb(0xFFEFC0)
        beamMat.emission.contents = rgb(0xFFE9AE)
        beamMat.transparency = 0.16
        beamMat.blendMode = .add
        beamMat.writesToDepthBuffer = false
        beamMat.isDoubleSided = true

        let beam = SCNNode.cone(top: 0.1, bottom: 6.0, height: 46, beamMat, segments: 10)
        beam.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        beam.position = SCNVector3(0, height + 2.7, -23)
        let pivot = SCNNode()
        pivot.addChildNode(beam)
        pivot.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 14)))
        root.addChildNode(pivot)

        let light = SCNLight()
        light.type = .omni
        light.color = rgb(0xFFE9AE)
        light.intensity = 900
        light.attenuationEndDistance = 60
        let ln = SCNNode()
        ln.light = light
        ln.position = SCNVector3(0, height + 2.7, 0)
        root.addChildNode(ln)

        return Built(node: root, name: name, radius: island ? 12 : 3.6, floatsOnWater: island)
    }

    // MARK: Alien

    private static func giantMushroom(_ rng: inout SeededRandom) -> Built {
        let root = SCNNode()
        let stalkMat = GeometryKit.material(rgb(0x9A90C8))
        let glow = rgb(0x6FE8C8)
        let capMat = GeometryKit.material(glow, emission: glow.withAlphaComponent(0.9))

        let height = rng.range(17, 22)
        let stalk = SCNNode.cone(top: 1.2, bottom: 2.4, height: height, stalkMat, segments: 12)
        stalk.position = SCNVector3(0, height / 2, 0)
        root.addChildNode(stalk)

        let capR = rng.range(9, 12)
        let cap = SCNNode.sphere(capR, capMat, segments: 18)
        cap.scale = SCNVector3(1.15, 0.5, 1.15)
        cap.position = SCNVector3(0, height + 1.5, 0)
        root.addChildNode(cap)

        // Gills underneath, throwing light down on the ground.
        let gills = SCNNode.cone(top: capR * 0.92, bottom: 0.6, height: 2.4, capMat, segments: 16)
        gills.position = SCNVector3(0, height, 0)
        root.addChildNode(gills)

        let light = SCNLight()
        light.type = .omni
        light.color = glow
        light.intensity = 1100
        light.attenuationEndDistance = 55
        let ln = SCNNode()
        ln.light = light
        ln.position = SCNVector3(0, height - 1, 0)
        root.addChildNode(ln)

        // A few smaller ones keeping it company.
        for _ in 0..<4 {
            let small = PropFactory.prototype(.glowMushroom, seed: UInt64(rng.next() * 90000))
            let a = rng.range(0, 2 * .pi)
            let d = rng.range(7, 15)
            small.position = SCNVector3(cos(a) * d, 0, sin(a) * d)
            small.scale = SCNVector3(2.2, 2.2, 2.2)
            root.addChildNode(small)
        }
        return Built(node: root, name: "The Lantern", radius: 3.0)
    }

    // MARK: Moon

    private static func monolith(_ rng: inout SeededRandom) -> Built {
        let root = SCNNode()
        let slab = SCNMaterial()
        slab.lightingModel = .physicallyBased
        slab.diffuse.contents = rgb(0x121319)
        slab.metalness.contents = 0.5
        slab.roughness.contents = 0.12

        let height = rng.range(18, 23)
        let stone = SCNNode.box(5.0, height, 1.6, chamfer: 0.06, slab)
        stone.position = SCNVector3(0, height / 2, 0)
        root.addChildNode(stone)

        // A small lander keeping it company.
        let hull = GeometryKit.material(rgb(0xD8D8E0), metal: true, roughness: 0.35)
        let gold = GeometryKit.material(rgb(0xD8B25E), metal: true, roughness: 0.3)
        let body = SCNNode.box(3.0, 2.0, 3.0, chamfer: 0.4, gold)
        body.position = SCNVector3(9, 2.4, 3)
        root.addChildNode(body)
        for i in 0..<4 {
            let a = Float(i) / 4 * 2 * .pi + .pi / 4
            let leg = SCNNode.cyl(radius: 0.14, height: 3.0, hull, segments: 6)
            leg.position = SCNVector3(9 + cos(a) * 1.9, 1.1, 3 + sin(a) * 1.9)
            leg.eulerAngles = SCNVector3(cos(a) * 0.45, 0, -sin(a) * 0.45)
            root.addChildNode(leg)
        }
        return Built(node: root, name: "The Monolith", radius: 3.4)
    }

    // MARK: Space

    private static func gate(_ rng: inout SeededRandom) -> Built {
        let root = SCNNode()
        let hull = GeometryKit.material(rgb(0xB9BCCC), metal: true, roughness: 0.3)

        let torus = SCNTorus(ringRadius: 22, pipeRadius: 1.8)
        torus.ringSegmentCount = 32
        torus.pipeSegmentCount = 10
        torus.materials = [hull]
        let ring = SCNNode(geometry: torus)
        ring.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        root.addChildNode(ring)

        let glow = GeometryKit.material(rgb(0xB9A6F0), emission: rgb(0x8E6FE0))
        for i in 0..<10 {
            let a = Float(i) / 10 * 2 * .pi
            let lamp = SCNNode.sphere(0.85, glow, segments: 8)
            lamp.position = SCNVector3(cos(a) * 22, sin(a) * 22, 0)
            root.addChildNode(lamp)
        }
        let inner = SCNMaterial()
        inner.lightingModel = .constant
        inner.diffuse.contents = rgb(0x6E5AB8)
        inner.emission.contents = rgb(0x4E3E96)
        inner.transparency = 0.22
        inner.blendMode = .add
        inner.writesToDepthBuffer = false
        inner.isDoubleSided = true
        let disc = SCNNode(geometry: SCNPlane(width: 42, height: 42))
        disc.geometry?.materials = [inner]
        root.addChildNode(disc)

        root.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 90)))
        _ = rng.next()
        return Built(node: root, name: "The Gate", radius: 0)
    }
}
