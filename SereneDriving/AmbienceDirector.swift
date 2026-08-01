import SceneKit
import simd

/// Every so often something small and lovely happens nearby: a dolphin breaks the
/// surface, a deer wanders past, a star falls. Nothing to catch, nothing to score —
/// you either notice it or you don't.
final class AmbienceDirector {

    let root = SCNNode()

    private var biome: Biome
    private var timer: Float
    private var rng = SeededRandom(9_137)

    init(biome: Biome) {
        self.biome = biome
        self.timer = 6
    }

    func reset(biome: Biome) {
        self.biome = biome
        root.childNodes.forEach { $0.removeFromParentNode() }
        timer = rng.range(5, 11)
    }

    func update(dt: Float, around p: SIMD3<Float>, heading: Float) {
        timer -= dt
        guard timer <= 0 else { return }
        timer = rng.range(10, 22)
        spawn(around: p, heading: heading)
    }

    // MARK: - Casting

    private func spawn(around p: SIMD3<Float>, heading: Float) {
        let pick = rng.next()
        switch biome.kind {
        case .forest:
            pick < 0.5 ? deer(near: p, heading: heading) : birds(near: p, heading: heading)
        case .snow:
            pick < 0.42 ? deer(near: p, heading: heading) : birds(near: p, heading: heading)
        case .desert:
            pick < 0.5 ? tumbleweed(near: p, heading: heading) : birds(near: p, heading: heading)
        case .beach:
            pick < 0.5 ? dolphin(near: p, heading: heading) : birds(near: p, heading: heading)
        case .ocean:
            pick < 0.68 ? dolphin(near: p, heading: heading) : birds(near: p, heading: heading)
        case .moon:
            shootingStar(near: p, heading: heading)
        case .space:
            pick < 0.6 ? shootingStar(near: p, heading: heading) : comet(near: p, heading: heading)
        case .autumn:
            pick < 0.5 ? deer(near: p, heading: heading) : birds(near: p, heading: heading)
        case .canyon:
            pick < 0.55 ? tumbleweed(near: p, heading: heading) : birds(near: p, heading: heading)
        case .saltflats:
            pick < 0.4 ? tumbleweed(near: p, heading: heading) : birds(near: p, heading: heading)
        case .volcano:
            pick < 0.5 ? shootingStar(near: p, heading: heading) : birds(near: p, heading: heading)
        case .alien:
            pick < 0.5 ? shootingStar(near: p, heading: heading) : birds(near: p, heading: heading)
        }
    }

    /// A spot in front of the player, off to one side.
    private func stageSpot(_ p: SIMD3<Float>, _ heading: Float, distance: ClosedRange<Float>,
                           lateral: ClosedRange<Float>) -> SIMD2<Float> {
        let f = SIMD2(-sin(heading), -cos(heading))
        let r = SIMD2(-f.y, f.x)
        let side: Float = rng.chance(0.5) ? 1 : -1
        return SIMD2(p.x, p.z)
            + f * rng.range(distance.lowerBound, distance.upperBound)
            + r * side * rng.range(lateral.lowerBound, lateral.upperBound)
    }

    private func present(_ node: SCNNode, life: TimeInterval) {
        node.opacity = 0
        root.addChildNode(node)
        node.runAction(.sequence([
            .fadeOpacity(to: 1, duration: 1.2),
            .wait(duration: max(life - 2.4, 0.5)),
            .fadeOpacity(to: 0, duration: 1.2),
            .removeFromParentNode(),
        ]))
    }

    // MARK: - Deer

    private func deer(near p: SIMD3<Float>, heading: Float) {
        let spot = stageSpot(p, heading, distance: 26...58, lateral: 6...30)
        let body = buildDeer(snowy: biome.kind == .snow)
        let walkHeading = rng.range(0, 2 * .pi)
        let dir = SIMD2(-sin(walkHeading), -cos(walkHeading))
        let duration: Float = 26

        body.position = SCNVector3(spot.x, biome.height(spot), spot.y)
        body.eulerAngles = SCNVector3(0, walkHeading, 0)

        let speed: Float = 1.5
        let walk = SCNAction.customAction(duration: TimeInterval(duration)) { [weak self] node, elapsed in
            guard let self else { return }
            let t = Float(elapsed)
            let xz = spot + dir * speed * t
            let ground = self.biome.height(xz)
            node.position = SCNVector3(xz.x, ground + abs(sin(t * 4.4)) * 0.06, xz.y)
        }
        body.runAction(walk)
        present(body, life: TimeInterval(duration))
    }

    private func buildDeer(snowy: Bool) -> SCNNode {
        let root = SCNNode()
        let coat = GeometryKit.material(rgb(snowy ? 0xB9A894 : 0x9A6F4A))
        let dark = GeometryKit.material(rgb(0x4A3A2C))

        let torso = SCNNode.box(0.5, 0.62, 1.35, chamfer: 0.22, coat)
        torso.position = SCNVector3(0, 1.05, 0)
        root.addChildNode(torso)

        let neck = SCNNode.box(0.3, 0.62, 0.3, chamfer: 0.12, coat)
        neck.position = SCNVector3(0, 1.42, -0.62)
        neck.eulerAngles = SCNVector3(0.35, 0, 0)
        root.addChildNode(neck)

        let head = SCNNode.box(0.28, 0.28, 0.52, chamfer: 0.12, coat)
        head.position = SCNVector3(0, 1.72, -0.86)
        root.addChildNode(head)

        for s in [Float(-1), 1] {
            let antler = SCNNode.cone(top: 0.01, bottom: 0.05, height: 0.42, dark, segments: 5)
            antler.position = SCNVector3(s * 0.1, 1.98, -0.82)
            antler.eulerAngles = SCNVector3(-0.2, 0, s * 0.4)
            root.addChildNode(antler)
        }
        for x in [Float(-0.18), 0.18] {
            for z in [Float(-0.48), 0.5] {
                let leg = SCNNode.cyl(radius: 0.06, height: 0.78, dark, segments: 5)
                leg.position = SCNVector3(x, 0.39, z)
                root.addChildNode(leg)
            }
        }
        let tail = SCNNode.sphere(0.11, coat, segments: 7)
        tail.position = SCNVector3(0, 1.25, 0.66)
        root.addChildNode(tail)
        return root
    }

    // MARK: - Birds

    private func birds(near p: SIMD3<Float>, heading: Float) {
        let flock = SCNNode()
        let count = Int(rng.range(4, 7.99))
        let tint = biome.kind == .beach || biome.kind == .ocean ? rgb(0xF4F6F8) : rgb(0x3E4450)

        for i in 0..<count {
            let bird = buildBird(tint: tint)
            let row = Float(i / 2), side: Float = i % 2 == 0 ? -1 : 1
            bird.position = SCNVector3(side * row * 1.5, row * 0.35, row * 2.0)
            // wings beat, each bird slightly out of phase
            let beat = SCNAction.sequence([
                .rotateBy(x: 0, y: 0, z: CGFloat(0.5), duration: 0.42),
                .rotateBy(x: 0, y: 0, z: CGFloat(-0.5), duration: 0.42),
            ])
            beat.timingMode = .easeInEaseOut
            bird.childNodes.first?.runAction(.repeatForever(beat))
            bird.childNodes.last?.runAction(.repeatForever(.sequence([
                .rotateBy(x: 0, y: 0, z: CGFloat(-0.5), duration: 0.42),
                .rotateBy(x: 0, y: 0, z: CGFloat(0.5), duration: 0.42),
            ])))
            flock.addChildNode(bird)
        }

        let spot = stageSpot(p, heading, distance: 40...80, lateral: 10...40)
        let flightHeading = rng.range(0, 2 * .pi)
        let dir = SIMD2(-sin(flightHeading), -cos(flightHeading))
        let baseY = (biome.hasTerrain ? biome.height(spot) : 0) + rng.range(16, 30)
        let duration: Float = 24
        let speed: Float = 7

        flock.position = SCNVector3(spot.x, baseY, spot.y)
        flock.eulerAngles = SCNVector3(0, flightHeading, 0)
        flock.runAction(.customAction(duration: TimeInterval(duration)) { node, elapsed in
            let t = Float(elapsed)
            let xz = spot + dir * speed * t
            node.position = SCNVector3(xz.x, baseY + sin(t * 0.5) * 1.6, xz.y)
        })
        present(flock, life: TimeInterval(duration))
    }

    private func buildBird(tint: UIColor) -> SCNNode {
        let bird = SCNNode()
        let mat = GeometryKit.material(tint)
        let bodyNode = SCNNode.cone(top: 0.02, bottom: 0.09, height: 0.42, mat, segments: 5)
        bodyNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        for s in [Float(-1), 1] {
            let wing = SCNNode.box(0.62, 0.02, 0.16, chamfer: 0.01, mat)
            wing.position = SCNVector3(s * 0.32, 0, 0)
            let pivot = SCNNode()
            pivot.addChildNode(wing)
            bird.addChildNode(pivot)
        }
        bird.addChildNode(bodyNode)
        return bird
    }

    // MARK: - Dolphin

    private func dolphin(near p: SIMD3<Float>, heading: Float) {
        let pod = SCNNode()
        let count = Int(rng.range(1, 3.49))
        let spot = stageSpot(p, heading, distance: 22...50, lateral: 8...26)
        let level = biome.waterLevel ?? 0
        let swimHeading = rng.range(0, 2 * .pi)
        let dir = SIMD2(-sin(swimHeading), -cos(swimHeading))
        let speed: Float = 6.5
        let duration: Float = 16

        for i in 0..<count {
            let d = buildDolphin()
            let lag = Float(i) * 0.55
            let lateral = Float(i) * 2.4 - Float(count - 1) * 1.2
            let side = SIMD2(-dir.y, dir.x)
            d.eulerAngles = SCNVector3(0, swimHeading, 0)

            d.runAction(.customAction(duration: TimeInterval(duration)) { node, elapsed in
                let t = Float(elapsed) - lag
                let xz = spot + side * lateral + dir * speed * max(t, 0)
                // Leap every few seconds: a clean parabola out of the water.
                let cycle = fmodf(max(t, 0), 4.2) / 4.2
                let arc = sin(Float.pi * simd_clamp(cycle * 2.1, 0, 1))
                let y = level - 0.5 + arc * 3.0
                node.position = SCNVector3(xz.x, y, xz.y)
                let pitch = cos(Float.pi * simd_clamp(cycle * 2.1, 0, 1)) * 0.9
                node.eulerAngles = SCNVector3(-pitch, swimHeading, 0)
            })
            pod.addChildNode(d)
        }
        present(pod, life: TimeInterval(duration))
    }

    private func buildDolphin() -> SCNNode {
        let d = SCNNode()
        let skin = GeometryKit.material(rgb(0x6E8CA8), metal: true, roughness: 0.35)
        let belly = GeometryKit.material(rgb(0xE4EDF2))

        let body = SCNNode(geometry: GeometryKit.blob(radius: 0.62, roughness: 0.06,
                                                      color: vec(0x6E8CA8), seed: 42))
        body.scale = SCNVector3(0.62, 0.62, 2.1)
        d.addChildNode(body)

        let snout = SCNNode.cone(top: 0.04, bottom: 0.22, height: 0.7, skin, segments: 8)
        snout.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        snout.position = SCNVector3(0, -0.02, -1.4)
        d.addChildNode(snout)

        let under = SCNNode.box(0.34, 0.1, 1.3, chamfer: 0.05, belly)
        under.position = SCNVector3(0, -0.32, 0.05)
        d.addChildNode(under)

        let dorsal = SCNNode.cone(top: 0.02, bottom: 0.24, height: 0.5, skin, segments: 5)
        dorsal.scale = SCNVector3(1, 1, 0.35)
        dorsal.position = SCNVector3(0, 0.5, 0.1)
        dorsal.eulerAngles = SCNVector3(0.4, 0, 0)
        d.addChildNode(dorsal)

        for s in [Float(-1), 1] {
            let fin = SCNNode.cone(top: 0.02, bottom: 0.2, height: 0.46, skin, segments: 5)
            fin.scale = SCNVector3(1, 1, 0.3)
            fin.position = SCNVector3(s * 0.34, -0.18, -0.5)
            fin.eulerAngles = SCNVector3(0.5, 0, s * 1.2)
            d.addChildNode(fin)
        }

        let tail = SCNNode.cone(top: 0.5, bottom: 0.02, height: 0.4, skin, segments: 5)
        tail.scale = SCNVector3(1, 1, 0.22)
        tail.position = SCNVector3(0, 0, 1.4)
        tail.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        d.addChildNode(tail)
        return d
    }

    // MARK: - Tumbleweed

    private func tumbleweed(near p: SIMD3<Float>, heading: Float) {
        let spot = stageSpot(p, heading, distance: 22...50, lateral: 5...22)
        let node = SCNNode(geometry: GeometryKit.blob(radius: 0.72, roughness: 0.42,
                                                      color: vec(0xB79A66), seed: 771))
        let rollHeading = rng.range(0, 2 * .pi)
        let dir = SIMD2(-sin(rollHeading), -cos(rollHeading))
        let speed: Float = 5.5
        let duration: Float = 20

        node.runAction(.customAction(duration: TimeInterval(duration)) { [weak self] n, elapsed in
            guard let self else { return }
            let t = Float(elapsed)
            let xz = spot + dir * speed * t
            let ground = self.biome.height(xz)
            n.position = SCNVector3(xz.x, ground + 0.7 + abs(sin(t * 5)) * 0.25, xz.y)
        })
        node.runAction(.repeatForever(.rotateBy(x: CGFloat(cos(rollHeading)) * 7,
                                                y: 0.4,
                                                z: CGFloat(-sin(rollHeading)) * 7,
                                                duration: 2)))
        present(node, life: TimeInterval(duration))
    }

    // MARK: - Sky

    private func shootingStar(near p: SIMD3<Float>, heading: Float) {
        let start = stageSpot(p, heading, distance: 90...170, lateral: 30...110)
        let node = SCNNode()
        let core = SCNNode.sphere(0.5, GeometryKit.material(rgb(0xFFF6E0), emission: rgb(0xFFFFFF)), segments: 8)
        node.addChildNode(core)

        let trail = SCNParticleSystem()
        trail.particleImage = SkyFactory.softDot
        trail.birthRate = 420
        trail.particleLifeSpan = 1.1
        trail.particleSize = 0.6
        trail.particleSizeVariation = 0.3
        trail.particleColor = rgb(0xCFE2FF)
        trail.particleVelocity = 0.4
        trail.spreadingAngle = 180
        trail.blendMode = .additive
        trail.isAffectedByGravity = false
        trail.isLightingEnabled = false
        let fade = CAKeyframeAnimation()
        fade.values = [0.9, 0.0]
        fade.keyTimes = [0.0, 1.0]
        fade.duration = 1
        trail.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        node.addParticleSystem(trail)

        let baseY = (biome.hasTerrain ? biome.height(start) : 0) + rng.range(70, 130)
        let travel = rng.range(0, 2 * .pi)
        let dir = SIMD2(-sin(travel), -cos(travel))
        let speed: Float = 60
        let duration: Float = 3.0

        node.position = SCNVector3(start.x, baseY, start.y)
        node.runAction(.customAction(duration: TimeInterval(duration)) { n, elapsed in
            let t = Float(elapsed)
            let xz = start + dir * speed * t
            n.position = SCNVector3(xz.x, baseY - t * 12, xz.y)
        })
        node.opacity = 1
        root.addChildNode(node)
        node.runAction(.sequence([
            .wait(duration: TimeInterval(duration) - 0.8),
            .fadeOpacity(to: 0, duration: 0.8),
            .removeFromParentNode(),
        ]))
    }

    private func comet(near p: SIMD3<Float>, heading: Float) {
        let start = stageSpot(p, heading, distance: 120...220, lateral: 40...140)
        let node = SCNNode()
        let core = SCNNode(geometry: GeometryKit.blob(radius: 2.4, roughness: 0.3,
                                                      color: vec(0x8E86A8), seed: 313))
        node.addChildNode(core)

        let halo = SCNNode.sphere(3.6, GeometryKit.material(rgb(0x9FD8FF), emission: rgb(0x6FB8F0)), segments: 12)
        halo.opacity = 0.35
        node.addChildNode(halo)

        let tail = SCNParticleSystem()
        tail.particleImage = SkyFactory.softDot
        tail.birthRate = 260
        tail.particleLifeSpan = 3.2
        tail.particleSize = 1.6
        tail.particleSizeVariation = 0.9
        tail.particleColor = rgb(0xAFD8FF)
        tail.particleVelocity = 1.2
        tail.spreadingAngle = 180
        tail.blendMode = .additive
        tail.isAffectedByGravity = false
        tail.isLightingEnabled = false
        let fade = CAKeyframeAnimation()
        fade.values = [0.6, 0.0]
        fade.keyTimes = [0.0, 1.0]
        fade.duration = 1
        tail.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        node.addParticleSystem(tail)

        let travel = rng.range(0, 2 * .pi)
        let dir = SIMD2(-sin(travel), -cos(travel))
        let baseY = rng.range(-25, 45)
        let duration: Float = 22

        node.runAction(.customAction(duration: TimeInterval(duration)) { n, elapsed in
            let t = Float(elapsed)
            let xz = start + dir * 16 * t
            n.position = SCNVector3(xz.x, baseY, xz.y)
        })
        core.runAction(.repeatForever(.rotateBy(x: 0.4, y: 0.7, z: 0.2, duration: 18)))
        present(node, life: TimeInterval(duration))
    }
}
