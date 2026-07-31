import SceneKit
import simd

/// A built vehicle plus the sub-nodes the controller animates.
final class VehicleRig {
    let root = SCNNode()
    let tilt = SCNNode()          // pitch / roll go here, so the body leans but the heading stays clean
    var wheelSpinners: [SCNNode] = []
    var steerHolders: [SCNNode] = []
    var glowNodes: [SCNNode] = []
    var driftEmitters: [SCNNode] = []
    var headlights: [SCNNode] = []
    var kind: VehicleKind = .car

    /// How high the origin sits above the ground.
    var rideHeight: Float = 0.5
    var wheelRadius: Float = 0.42
    /// Half the distance between the left and right wheels — where marks are laid.
    var trackHalfWidth: Float = 0.95
    var trackWidth: Float = 0.34
    /// Radius used against scenery. Zero means nothing to collide with.
    var collisionRadius: Float = 1.2

    init() { root.addChildNode(tilt) }

    /// Resize the whole vehicle, keeping ride height, wheels and collision in step.
    func applyScale(_ s: Float) {
        tilt.scale = SCNVector3(s, s, s)
        rideHeight *= s
        wheelRadius *= s
        trackHalfWidth *= s
        trackWidth *= s
        collisionRadius *= s
    }
}

enum VehicleFactory {

    static func make(_ kind: VehicleKind) -> VehicleRig {
        switch kind {
        case .car:       return car()
        case .quad:      return quad()
        case .boat:      return boat()
        case .rover:     return rover()
        case .spaceship: return spaceship()
        }
    }

    // MARK: - Shared

    private static func wheel(radius: Float, width: Float, at p: SIMD3<Float>,
                              rig: VehicleRig, steers: Bool, hub: UIColor = rgb(0xC9C9CE)) {
        let holder = SCNNode()
        holder.position = SCNVector3(p.x, p.y, p.z)

        let spinner = SCNNode()
        let tyre = SCNNode.cyl(radius: radius, height: width,
                               GeometryKit.material(rgb(0x3A3A40)), segments: 14)
        tyre.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        spinner.addChildNode(tyre)

        let rim = SCNNode.cyl(radius: radius * 0.52, height: width * 1.04,
                              GeometryKit.material(hub), segments: 10)
        rim.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        spinner.addChildNode(rim)

        holder.addChildNode(spinner)
        rig.tilt.addChildNode(holder)
        rig.wheelSpinners.append(spinner)
        if steers { rig.steerHolders.append(holder) }
    }

    /// Smoke pouring off the rear tyres while sliding.
    private static func addDriftEmitters(_ rig: VehicleRig, at points: [SIMD3<Float>], tint: UIColor) {
        for p in points {
            let node = SCNNode()
            node.position = SCNVector3(p.x, p.y, p.z)
            let ps = ParticleFactory.tyreSmoke(tint: tint)
            node.addParticleSystem(ps)
            rig.tilt.addChildNode(node)
            rig.driftEmitters.append(node)
        }
    }

    /// A forward beam, dark by default — the world turns it on when night falls.
    private static func addHeadlight(_ rig: VehicleRig, at p: SIMD3<Float>, spread: CGFloat = 55) {
        let light = SCNLight()
        light.type = .spot
        light.color = rgb(0xFFF1CE)
        light.intensity = 0
        light.spotInnerAngle = 18
        light.spotOuterAngle = spread
        light.attenuationStartDistance = 3
        light.attenuationEndDistance = 52
        light.castsShadow = false
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(p.x, p.y, p.z)
        node.eulerAngles = SCNVector3(-0.16, 0, 0)   // aim slightly down the road
        rig.tilt.addChildNode(node)
        rig.headlights.append(node)
    }

    private static func glassMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = rgb(0x2A3B49)
        m.metalness.contents = 0.2
        m.roughness.contents = 0.08
        m.transparency = 0.72
        return m
    }

    // MARK: - Car

    private static func car() -> VehicleRig {
        let rig = VehicleRig()
        rig.kind = .car
        rig.rideHeight = 0.44
        rig.wheelRadius = 0.42

        let paint = GeometryKit.material(rgb(0x8FB2C4), metal: true, roughness: 0.5)
        let accent = GeometryKit.material(rgb(0xD8CFBA), metal: true, roughness: 0.5)

        let body = SCNNode.box(1.95, 0.62, 4.05, chamfer: 0.28, paint)
        body.position = SCNVector3(0, 0.52, 0)
        rig.tilt.addChildNode(body)

        let lower = SCNNode.box(2.02, 0.30, 3.6, chamfer: 0.14, accent)
        lower.position = SCNVector3(0, 0.30, 0)
        rig.tilt.addChildNode(lower)

        let cabin = SCNNode.box(1.66, 0.62, 1.95, chamfer: 0.30, accent)
        cabin.position = SCNVector3(0, 1.02, 0.16)
        rig.tilt.addChildNode(cabin)

        let glass = SCNNode.box(1.60, 0.46, 1.86, chamfer: 0.22, glassMaterial())
        glass.position = SCNVector3(0, 1.06, 0.16)
        rig.tilt.addChildNode(glass)

        // roof rack — a little character
        let rack = GeometryKit.material(rgb(0x6E6A62), metal: true, roughness: 0.5)
        for x in [Float(-0.55), 0.55] {
            let bar = SCNNode.box(0.07, 0.07, 1.5, chamfer: 0.03, rack)
            bar.position = SCNVector3(x, 1.38, 0.2)
            rig.tilt.addChildNode(bar)
        }
        let luggage = SCNNode.box(1.05, 0.24, 1.1, chamfer: 0.08,
                                  GeometryKit.material(rgb(0xB98D5C)))
        luggage.position = SCNVector3(0, 1.5, 0.2)
        rig.tilt.addChildNode(luggage)

        // lights
        let head = GeometryKit.material(rgb(0xFFF6D8), emission: rgb(0xE8D8A8))
        let tail = GeometryKit.material(rgb(0xE87F6A), emission: rgb(0xB8442C))
        for x in [Float(-0.62), 0.62] {
            let h = SCNNode.sphere(0.15, head, segments: 9)
            h.position = SCNVector3(x, 0.58, -1.98)
            h.scale = SCNVector3(1, 0.7, 0.5)
            rig.tilt.addChildNode(h)
            rig.glowNodes.append(h)

            let t = SCNNode.box(0.34, 0.14, 0.08, chamfer: 0.04, tail)
            t.position = SCNVector3(x, 0.62, 2.0)
            rig.tilt.addChildNode(t)
        }

        wheel(radius: 0.42, width: 0.34, at: SIMD3(-0.98, 0.42, -1.32), rig: rig, steers: true)
        wheel(radius: 0.42, width: 0.34, at: SIMD3(0.98, 0.42, -1.32), rig: rig, steers: true)
        wheel(radius: 0.42, width: 0.34, at: SIMD3(-0.98, 0.42, 1.38), rig: rig, steers: false)
        wheel(radius: 0.42, width: 0.34, at: SIMD3(0.98, 0.42, 1.38), rig: rig, steers: false)

        addHeadlight(rig, at: SIMD3(-0.62, 0.58, -2.1))
        addHeadlight(rig, at: SIMD3(0.62, 0.58, -2.1))
        rig.trackHalfWidth = 0.98
        rig.trackWidth = 0.36
        rig.collisionRadius = 1.25
        addDriftEmitters(rig, at: [SIMD3(-0.98, 0.18, 1.42), SIMD3(0.98, 0.18, 1.42)],
                         tint: UIColor(white: 0.95, alpha: 1))
        rig.applyScale(0.8)
        return rig
    }

    // MARK: - Quad

    private static func quad() -> VehicleRig {
        let rig = VehicleRig()
        rig.kind = .quad
        rig.rideHeight = 0.52
        rig.wheelRadius = 0.5

        let paint = GeometryKit.material(rgb(0xE3A55C), metal: true, roughness: 0.45)
        let dark = GeometryKit.material(rgb(0x4A4A52), metal: true, roughness: 0.5)

        let chassis = SCNNode.box(1.05, 0.34, 2.2, chamfer: 0.16, dark)
        chassis.position = SCNVector3(0, 0.62, 0)
        rig.tilt.addChildNode(chassis)

        let hood = SCNNode.box(1.25, 0.42, 1.0, chamfer: 0.2, paint)
        hood.position = SCNVector3(0, 0.86, -0.62)
        rig.tilt.addChildNode(hood)

        let rear = SCNNode.box(1.3, 0.36, 0.9, chamfer: 0.18, paint)
        rear.position = SCNVector3(0, 0.82, 0.82)
        rig.tilt.addChildNode(rear)

        let seat = SCNNode.box(0.66, 0.3, 0.95, chamfer: 0.14, GeometryKit.material(rgb(0x38343A)))
        seat.position = SCNVector3(0, 1.02, 0.06)
        rig.tilt.addChildNode(seat)

        // handlebars
        let bar = SCNNode.cyl(radius: 0.05, height: 0.9, dark, segments: 8)
        bar.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        bar.position = SCNVector3(0, 1.26, -0.62)
        rig.tilt.addChildNode(bar)
        let stem = SCNNode.cyl(radius: 0.06, height: 0.42, dark, segments: 8)
        stem.position = SCNVector3(0, 1.08, -0.62)
        rig.tilt.addChildNode(stem)

        let head = GeometryKit.material(rgb(0xFFF6D8), emission: rgb(0xFFEFC0))
        let lamp = SCNNode.sphere(0.16, head, segments: 9)
        lamp.position = SCNVector3(0, 1.0, -1.12)
        rig.tilt.addChildNode(lamp)
        rig.glowNodes.append(lamp)

        wheel(radius: 0.5, width: 0.42, at: SIMD3(-0.72, 0.5, -0.86), rig: rig, steers: true, hub: rgb(0xB9843F))
        wheel(radius: 0.5, width: 0.42, at: SIMD3(0.72, 0.5, -0.86), rig: rig, steers: true, hub: rgb(0xB9843F))
        wheel(radius: 0.54, width: 0.48, at: SIMD3(-0.74, 0.54, 0.92), rig: rig, steers: false, hub: rgb(0xB9843F))
        wheel(radius: 0.54, width: 0.48, at: SIMD3(0.74, 0.54, 0.92), rig: rig, steers: false, hub: rgb(0xB9843F))

        addHeadlight(rig, at: SIMD3(0, 1.0, -1.25), spread: 62)
        rig.trackHalfWidth = 0.74
        rig.trackWidth = 0.5
        rig.collisionRadius = 0.98
        addDriftEmitters(rig, at: [SIMD3(-0.74, 0.2, 0.98), SIMD3(0.74, 0.2, 0.98)],
                         tint: rgb(0xEEDFC0))
        return rig
    }

    // MARK: - Boat

    private static func boat() -> VehicleRig {
        let rig = VehicleRig()
        rig.kind = .boat
        rig.rideHeight = 0.0

        let hullMat = GeometryKit.material(rgb(0xF2EDE2), metal: true, roughness: 0.4)
        let deckMat = GeometryKit.material(rgb(0xC79A63))
        let trim = GeometryKit.material(rgb(0x4E7FA0), metal: true, roughness: 0.4)

        let hull = SCNNode.box(1.9, 0.85, 4.4, chamfer: 0.42, hullMat)
        hull.position = SCNVector3(0, 0.16, 0.2)
        rig.tilt.addChildNode(hull)

        let bow = SCNNode.cone(top: 0.02, bottom: 0.95, height: 1.7, hullMat, segments: 10)
        bow.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        bow.position = SCNVector3(0, 0.16, -2.55)
        bow.scale = SCNVector3(1.0, 1.0, 0.85)
        rig.tilt.addChildNode(bow)

        let deck = SCNNode.box(1.72, 0.1, 4.0, chamfer: 0.05, deckMat)
        deck.position = SCNVector3(0, 0.58, 0.2)
        rig.tilt.addChildNode(deck)

        let stripe = SCNNode.box(1.95, 0.12, 4.42, chamfer: 0.05, trim)
        stripe.position = SCNVector3(0, 0.5, 0.2)
        rig.tilt.addChildNode(stripe)

        let cabin = SCNNode.box(1.25, 0.75, 1.5, chamfer: 0.22, hullMat)
        cabin.position = SCNVector3(0, 1.0, 0.55)
        rig.tilt.addChildNode(cabin)

        let windows = SCNNode.box(1.28, 0.36, 1.42, chamfer: 0.14, glassMaterial())
        windows.position = SCNVector3(0, 1.12, 0.55)
        rig.tilt.addChildNode(windows)

        let mast = SCNNode.cyl(radius: 0.05, height: 1.5, GeometryKit.material(rgb(0xE8E4DA)), segments: 7)
        mast.position = SCNVector3(0, 2.05, 0.9)
        rig.tilt.addChildNode(mast)

        let lamp = SCNNode.sphere(0.12, GeometryKit.material(rgb(0xFFE6A8), emission: rgb(0xFFD070)), segments: 8)
        lamp.position = SCNVector3(0, 2.85, 0.9)
        rig.tilt.addChildNode(lamp)
        rig.glowNodes.append(lamp)

        addHeadlight(rig, at: SIMD3(0, 1.4, -2.4), spread: 48)
        rig.trackHalfWidth = 0
        rig.collisionRadius = 1.75
        addDriftEmitters(rig, at: [SIMD3(-0.55, 0.15, 2.3), SIMD3(0.55, 0.15, 2.3)],
                         tint: UIColor(white: 1, alpha: 1))
        return rig
    }

    // MARK: - Rover

    private static func rover() -> VehicleRig {
        let rig = VehicleRig()
        rig.kind = .rover
        rig.rideHeight = 0.62
        rig.wheelRadius = 0.5

        let shell = GeometryKit.material(rgb(0xE4E6EA), metal: true, roughness: 0.38)
        let dark = GeometryKit.material(rgb(0x3E4250), metal: true, roughness: 0.45)
        let gold = GeometryKit.material(rgb(0xD8B25E), metal: true, roughness: 0.3)

        let chassis = SCNNode.box(1.6, 0.28, 3.3, chamfer: 0.1, dark)
        chassis.position = SCNVector3(0, 0.72, 0)
        rig.tilt.addChildNode(chassis)

        let cab = SCNNode.box(1.5, 0.7, 1.5, chamfer: 0.2, shell)
        cab.position = SCNVector3(0, 1.14, -0.55)
        rig.tilt.addChildNode(cab)

        let domeGlass = glassMaterial()
        domeGlass.diffuse.contents = rgb(0x6E8496)
        domeGlass.transparency = 0.6
        let dome = SCNNode.sphere(0.66, domeGlass, segments: 14)
        dome.position = SCNVector3(0, 1.42, -0.55)
        dome.scale = SCNVector3(1.05, 0.85, 1.0)
        rig.tilt.addChildNode(dome)

        let panel = SCNNode.box(1.9, 0.06, 1.5, chamfer: 0.02, gold)
        panel.position = SCNVector3(0, 1.12, 1.0)
        panel.eulerAngles = SCNVector3(-0.12, 0, 0)
        rig.tilt.addChildNode(panel)

        let dish = SCNNode.cone(top: 0.34, bottom: 0.03, height: 0.3, shell, segments: 12)
        dish.position = SCNVector3(0.5, 1.62, 0.6)
        dish.eulerAngles = SCNVector3(-0.5, 0, 0.3)
        rig.tilt.addChildNode(dish)

        let head = GeometryKit.material(rgb(0xEAF6FF), emission: rgb(0xBFE4FF))
        for x in [Float(-0.5), 0.5] {
            let l = SCNNode.sphere(0.12, head, segments: 8)
            l.position = SCNVector3(x, 1.0, -1.28)
            rig.tilt.addChildNode(l)
            rig.glowNodes.append(l)
        }

        for z in [Float(-1.15), 0, 1.2] {
            wheel(radius: 0.5, width: 0.3, at: SIMD3(-0.92, 0.62, z), rig: rig,
                  steers: z < -0.5, hub: rgb(0xA8ADBA))
            wheel(radius: 0.5, width: 0.3, at: SIMD3(0.92, 0.62, z), rig: rig,
                  steers: z < -0.5, hub: rgb(0xA8ADBA))
        }

        addHeadlight(rig, at: SIMD3(-0.5, 1.0, -1.4))
        addHeadlight(rig, at: SIMD3(0.5, 1.0, -1.4))
        rig.trackHalfWidth = 0.92
        rig.trackWidth = 0.32
        rig.collisionRadius = 1.15
        addDriftEmitters(rig, at: [SIMD3(-0.92, 0.2, 1.35), SIMD3(0.92, 0.2, 1.35)],
                         tint: rgb(0xD4D8E4))
        return rig
    }

    // MARK: - Spaceship

    private static func spaceship() -> VehicleRig {
        let rig = VehicleRig()
        rig.kind = .spaceship
        rig.rideHeight = 0

        let hull = GeometryKit.material(rgb(0xEFF1F6), metal: true, roughness: 0.3)
        let accent = GeometryKit.material(rgb(0x6E7FC4), metal: true, roughness: 0.35)

        let body = SCNNode.cone(top: 0.12, bottom: 0.85, height: 4.6, hull, segments: 14)
        body.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        body.position = SCNVector3(0, 0, -0.1)
        rig.tilt.addChildNode(body)

        let belly = SCNNode.box(1.5, 0.5, 2.6, chamfer: 0.24, accent)
        belly.position = SCNVector3(0, -0.42, 0.4)
        rig.tilt.addChildNode(belly)

        let canopy = SCNNode.sphere(0.62, glassMaterial(), segments: 14)
        canopy.position = SCNVector3(0, 0.3, -0.6)
        canopy.scale = SCNVector3(0.85, 0.62, 1.35)
        rig.tilt.addChildNode(canopy)

        for s in [Float(-1), 1] {
            let wing = SCNNode.box(2.3, 0.12, 1.5, chamfer: 0.06, hull)
            wing.position = SCNVector3(s * 1.5, -0.1, 1.0)
            wing.eulerAngles = SCNVector3(0, s * 0.30, s * -0.18)
            rig.tilt.addChildNode(wing)

            let fin = SCNNode.box(0.1, 0.9, 0.9, chamfer: 0.05, accent)
            fin.position = SCNVector3(s * 2.4, 0.35, 1.35)
            fin.eulerAngles = SCNVector3(0.25, 0, s * -0.15)
            rig.tilt.addChildNode(fin)
        }

        let engineGlow = GeometryKit.material(rgb(0x7FC4E8), emission: rgb(0x4E9CD8))
        for x in [Float(-0.55), 0.55] {
            let nacelle = SCNNode.cyl(radius: 0.32, height: 1.3, hull, segments: 12)
            nacelle.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            nacelle.position = SCNVector3(x, -0.25, 1.85)
            rig.tilt.addChildNode(nacelle)

            let flame = SCNNode.sphere(0.22, engineGlow, segments: 10)
            flame.position = SCNVector3(x, -0.25, 2.45)
            flame.scale = SCNVector3(1, 1, 1.5)
            rig.tilt.addChildNode(flame)
            rig.glowNodes.append(flame)

            let light = SCNLight()
            light.type = .omni
            light.color = rgb(0x7FC8FF)
            light.intensity = 110
            light.attenuationEndDistance = 12
            let ln = SCNNode()
            ln.light = light
            ln.position = SCNVector3(x, -0.25, 2.8)
            rig.tilt.addChildNode(ln)
        }

        rig.trackHalfWidth = 0
        rig.wheelRadius = 0
        rig.collisionRadius = 2.2
        return rig
    }
}
