import SceneKit
import simd

/// Live driving input, written by the on-screen control and read by the render loop.
final class ControlState {
    var steer: Float = 0
    var throttle: Float = 0
}

final class WorldScene: NSObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    let controls = ControlState()
    let audio = AmbientAudio()
    let haptics = Haptics()
    weak var model: GameModel?

    /// How long you spend in each place before the world gently changes.
    static let worldDuration: Float = 60

    private enum Phase {
        case driving
        case leaving(Float)
        case arriving(Float)
    }

    private let cameraNode = SCNNode()
    private let sunNode = SCNNode()
    private let ambientNode = SCNNode()
    private let worldRoot = SCNNode()
    private let particleHolder = SCNNode()

    private var terrain: TerrainSystem?
    private var landmarks: LandmarkSystem?
    private var diamonds: DiamondField?
    private var water: WaterSystem?
    private var tracks: TrackSystem?
    private var ambience: AmbienceDirector?
    private var rig: VehicleRig?
    private var vehicle: VehicleController?

    var mode: GameMode = .serene {
        didSet {
            vehicle?.setMode(mode)
            audio.setMode(mode)
            diamonds?.isActive = (mode == .speed)
        }
    }

    private var biomeIndex = 0
    private var mood = WorldMood()
    private var biome = Biome.all[0]
    private var moodRng = SeededRandom(20_260_731)

    private var lastTime: TimeInterval = 0
    private var totalTime: Float = 0
    private var timeInWorld: Float = 0
    private var phase: Phase = .arriving(0)
    private var smoothTarget = SIMD3<Float>(0, 0, 0)
    private var uiClock: Float = 0

    private let leaveDuration: Float = 1.5
    private let arriveDuration: Float = 2.0

    // MARK: - Setup

    func build() {
        scene.rootNode.addChildNode(worldRoot)
        scene.rootNode.addChildNode(particleHolder)

        let camera = SCNCamera()
        camera.fieldOfView = 68
        camera.projectionDirection = .vertical
        camera.zNear = 0.4
        camera.zFar = 1400
        camera.wantsHDR = true
        camera.bloomIntensity = 0.22
        camera.bloomThreshold = 0.82
        camera.bloomBlurRadius = 14
        camera.vignettingIntensity = 0.32
        camera.vignettingPower = 1.1
        camera.saturation = 1.06
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.35
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 6, 12)
        scene.rootNode.addChildNode(cameraNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.castsShadow = true
        sun.shadowMode = .forward
        sun.shadowSampleCount = 8
        sun.shadowRadius = 5
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.shadowColor = UIColor(white: 0, alpha: 0.34)
        sun.orthographicScale = 34
        sun.zNear = 1
        sun.zFar = 260
        sunNode.light = sun
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        loadWorld(index: 0, keepMomentum: false)
        audio.start()
        haptics.start()
    }

    // MARK: - Worlds

    private func loadWorld(index: Int, keepMomentum: Bool) {
        biomeIndex = index % Biome.all.count
        let base = Biome.all[biomeIndex]
        mood = WorldMood.random(for: base, using: &moodRng)
        biome = base.graded(mood)
        let b = biome

        // Tear down the previous world.
        terrain?.removeAll()
        terrain?.root.removeFromParentNode()
        landmarks?.root.removeFromParentNode()
        diamonds?.clear()
        diamonds?.root.removeFromParentNode()
        water?.node.removeFromParentNode()
        tracks?.node.removeFromParentNode()
        rig?.root.removeFromParentNode()
        particleHolder.removeAllParticleSystems()

        // Sky, light, fog.
        let sky = SkyFactory.sky(for: b, weather: mood.weather)
        scene.background.contents = sky
        scene.lightingEnvironment.contents = sky
        scene.lightingEnvironment.intensity = b.stars ? 0.7 : 1.0
        scene.fogColor = b.fogColor
        scene.fogStartDistance = b.fogStart
        scene.fogEndDistance = b.fogEnd
        scene.fogDensityExponent = 1.7

        sunNode.light?.color = b.sunColor
        sunNode.light?.intensity = b.sunIntensity * 0.85
        sunNode.light?.castsShadow = b.hasTerrain
        ambientNode.light?.color = b.ambientColor
        ambientNode.light?.intensity = b.ambientIntensity

        // Terrain + water.
        let t = TerrainSystem(biome: b)
        worldRoot.addChildNode(t.root)
        terrain = t

        let lm = landmarks ?? LandmarkSystem(biome: b)
        worldRoot.addChildNode(lm.root)
        landmarks = lm

        let df = diamonds ?? DiamondField(biome: b)
        df.reset(biome: b)
        df.isActive = (mode == .speed)
        worldRoot.addChildNode(df.root)
        diamonds = df

        let tr = TrackSystem(biome: b)
        worldRoot.addChildNode(tr.node)
        tracks = tr

        if let a = ambience {
            a.reset(biome: b)
        } else {
            let a = AmbienceDirector(biome: b)
            worldRoot.addChildNode(a.root)
            ambience = a
        }

        if let level = b.waterLevel {
            let w = WaterSystem(biome: b, level: level)
            worldRoot.addChildNode(w.node)
            water = w
        } else {
            water = nil
        }

        // Vehicle.
        let newRig = VehicleFactory.make(b.vehicle)
        worldRoot.addChildNode(newRig.root)
        let previous = vehicle
        let controller = VehicleController(rig: newRig, biome: b, water: water, mode: mode)
        controller.colliderSource = { [weak t, weak lm] p in
            var list = t?.colliders(near: p) ?? []
            if let c = lm?.collider { list.append(c) }
            return list
        }
        if let p = previous, keepMomentum {
            controller.position = p.position
            controller.heading = p.heading
            let carried = VehicleController.tuning(for: b.vehicle, mode: mode).maxSpeed
            controller.setLaunchSpeed(min(p.speed, carried) * 0.7)
        } else {
            controller.position = SIMD3(0, 0, 0)
            controller.heading = 0
        }
        if b.vehicle != .boat { controller.position = Self.dryGround(near: controller.position, in: b) }
        // Headlights come on when the world is dark enough to want them.
        if b.sunIntensity < 430 {
            let beam: CGFloat = b.hasTerrain ? 1250 : 500
            for h in newRig.headlights { h.light?.intensity = beam }
        }

        rig = newRig
        vehicle = controller

        // Make sure the ground exists before we drop the vehicle onto it.
        t.prime(around: controller.position)
        controller.teleportToSurface(time: totalTime)

        lm.place(biome: b, near: controller.position, rng: &moodRng)

        if let ps = ParticleFactory.system(for: b.particle) {
            particleHolder.addParticleSystem(ps)
        }
        if let ws = ParticleFactory.weatherSystem(for: mood.weather) {
            particleHolder.addParticleSystem(ws)
        }

        snapCamera()
        audio.setBiome(b)

        timeInWorld = 0
        phase = .arriving(0)

        audio.chime()
        haptics.arrival()

        let name = b.name, subtitle = b.subtitle
        DispatchQueue.main.async { [weak self] in
            self?.model?.announce(name: name, subtitle: subtitle, veil: b.fogColor)
        }
    }

    /// Nudge a spawn point onto dry land so a wheeled vehicle never starts at sea.
    private static func dryGround(near p: SIMD3<Float>, in biome: Biome) -> SIMD3<Float> {
        guard let level = biome.waterLevel else { return p }
        let start = SIMD2(p.x, p.z)
        if biome.height(start) > level + 1.5 { return p }

        var radius: Float = 24
        while radius < 900 {
            for step in 0..<12 {
                let a = Float(step) / 12 * 2 * .pi
                let candidate = start + SIMD2(cos(a), sin(a)) * radius
                if biome.height(candidate) > level + 1.5 {
                    return SIMD3(candidate.x, p.y, candidate.y)
                }
            }
            radius *= 1.6
        }
        return p
    }

    func skipToNextWorld() {
        if case .driving = phase { phase = .leaving(0) }
    }

    // MARK: - Camera

    private func cameraOffsets() -> (distance: Float, height: Float, lookAhead: Float) {
        switch biome.vehicle {
        case .car:       return (11.5, 4.4, 8)
        case .quad:      return (10.0, 4.0, 7)
        case .boat:      return (14.5, 5.4, 10)
        case .rover:     return (11.0, 4.4, 8)
        case .spaceship: return (18.0, 5.2, 15)
        }
    }

    private func snapCamera() {
        guard let v = vehicle else { return }
        let o = cameraOffsets()
        let f = v.forward
        let pos = SIMD3(v.position.x, v.visualY, v.position.z)
        cameraNode.position = SCNVector3(pos.x - f.x * o.distance, pos.y + o.height, pos.z - f.z * o.distance)
        smoothTarget = pos + f * o.lookAhead + SIMD3(0, 1.4, 0)
        cameraNode.look(at: SCNVector3(smoothTarget.x, smoothTarget.y, smoothTarget.z),
                        up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    private func updateCamera(dt: Float) {
        guard let v = vehicle else { return }
        let o = cameraOffsets()
        let f = v.forward
        let pos = SIMD3(v.position.x, v.visualY, v.position.z)

        // Pull back a touch as you speed up — it breathes.
        let stretch = 1 + v.normalizedSpeed * 0.22
        var desired = pos - f * (o.distance * stretch) + SIMD3(0, o.height + v.normalizedSpeed * 0.5, 0)

        if biome.hasTerrain {
            let ground = biome.height(SIMD2(desired.x, desired.z))
            let floor = max(ground, biome.waterLevel ?? -.greatestFiniteMagnitude) + 1.6
            desired.y = max(desired.y, floor)
        }

        let k = 1 - expf(-3.2 * dt)
        var current = SIMD3(Float(cameraNode.position.x), Float(cameraNode.position.y), Float(cameraNode.position.z))
        current += (desired - current) * k
        cameraNode.position = SCNVector3(current.x, current.y, current.z)

        let target = pos + f * o.lookAhead + SIMD3(0, 1.4, 0)
        smoothTarget += (target - smoothTarget) * (1 - expf(-4.5 * dt))
        cameraNode.look(at: SCNVector3(smoothTarget.x, smoothTarget.y, smoothTarget.z),
                        up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    private func updateSun(around p: SIMD3<Float>) {
        let el = biome.sunElevation * (.pi / 2)
        let az: Float = 2.4
        let dir = SIMD3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
        let anchor = p + SIMD3(0, 2, 0)
        let lightPos = anchor + dir * 90
        sunNode.position = SCNVector3(lightPos.x, lightPos.y, lightPos.z)
        sunNode.look(at: SCNVector3(anchor.x, anchor.y, anchor.z),
                     up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    // MARK: - Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastTime == 0 { lastTime = time }
        var dt = Float(time - lastTime)
        lastTime = time
        dt = min(max(dt, 0.0001), 0.05)
        totalTime += dt


        guard let v = vehicle else { return }

        // Phase handling — the world changes on its own, gently.
        var inputScale: Float = 1
        switch phase {
        case .driving:
            timeInWorld += dt
            if timeInWorld >= WorldScene.worldDuration { phase = .leaving(0) }
        case .leaving(let t):
            let nt = t + dt
            let p = min(nt / leaveDuration, 1)
            setVeil(p)
            if nt >= leaveDuration {
                loadWorld(index: biomeIndex + 1, keepMomentum: true)
            } else {
                phase = .leaving(nt)
            }
        case .arriving(let t):
            let nt = t + dt
            let p = 1 - min(nt / arriveDuration, 1)
            setVeil(p * p)
            phase = nt >= arriveDuration ? .driving : .arriving(nt)
        }

        var steer = controls.steer
        var throttle = controls.throttle
        if case .leaving = phase { inputScale = 0.6 }
        steer *= inputScale
        throttle *= inputScale

        v.update(dt: dt, steer: steer, throttle: throttle, time: totalTime)

        terrain?.update(around: v.position)
        water?.update(center: SIMD3(v.position.x, v.visualY, v.position.z), time: totalTime, dt: dt)
        if let rig {
            tracks?.update(position: SIMD3(v.position.x, v.visualY, v.position.z),
                           heading: v.heading,
                           halfWidth: rig.trackHalfWidth,
                           width: rig.trackWidth,
                           drift: v.driftAmount,
                           airborne: false)
        }
        ambience?.update(dt: dt, around: v.position, heading: v.heading)

        if let picked = diamonds?.update(around: v.position, heading: v.heading, time: totalTime), picked > 0 {
            audio.sparkle()
            haptics.impact(0.32)
            DispatchQueue.main.async { [weak self] in self?.model?.diamonds += picked }
        }

        if let found = landmarks?.update(playerAt: v.position) {
            haptics.discovery()
            audio.chime()
            DispatchQueue.main.async { [weak self] in self?.model?.reveal(landmark: found) }
        }
        updateCamera(dt: dt)
        updateSun(around: v.position)

        // Keep the drifting motes ahead of the camera — born at arm's length they
        // read as big blurry blobs instead of atmosphere.
        let motes = v.position + v.forward * 42 + SIMD3(0, 6, 0)
        particleHolder.position = SCNVector3(motes.x, v.visualY + 6, motes.z)

        audio.setSpeed(v.normalizedSpeed)
        audio.setDrift(v.driftAmount)

        // Surface texture under the wheels, plus a tap for anything we clipped.
        let feel = biome.surfaceFeel
        haptics.setTexture(intensity: v.normalizedSpeed * feel.grain * (0.55 + v.driftAmount * 0.7),
                           sharpness: feel.sharpness + v.driftAmount * 0.35)
        if let bump = v.consumeImpact() { haptics.impact(bump) }

        // HUD updates at a calm 10 Hz.
        uiClock += dt
        if uiClock > 0.1 {
            uiClock = 0
            let kmh = v.speedKmh
            DispatchQueue.main.async { [weak self] in self?.model?.speedKmh = kmh }
        }
    }

    private func setVeil(_ amount: Float) {
        let a = Double(min(max(amount, 0), 1))
        DispatchQueue.main.async { [weak self] in self?.model?.veilOpacity = a }
    }
}
