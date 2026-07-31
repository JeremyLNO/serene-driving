import SceneKit
import simd

/// A solid thing in the world you can bump into: trunk, boulder, satellite…
struct Collider {
    var position: SIMD2<Float>
    var radius: Float
}

/// Kinematic driving. Nothing to flip, nothing to break — but the body carries
/// real lateral inertia, so in Speed mode it slides through corners, and scenery
/// is solid: you nudge it aside and glide along instead of driving through it.
final class VehicleController {

    struct Tuning {
        var maxSpeed: Float
        var reverseSpeed: Float
        var accel: Float
        var brake: Float
        var drag: Float
        var steerRate: Float
        var bodyLean: Float
        var settle: Float          // how fast the body follows the ground
        var traction: Float        // how quickly sideways motion is scrubbed off
    }

    var position = SIMD3<Float>(0, 0, 0)
    var heading: Float = 0
    private(set) var velocity = SIMD3<Float>(0, 0, 0)

    private(set) var visualY: Float = 0
    private(set) var pitch: Float = 0
    private(set) var roll: Float = 0
    private(set) var slip: Float = 0          // sideways speed, m/s
    private var pendingImpact: Float = 0      // strength of the most recent bump, unread
    private var steerAngle: Float = 0
    private var wheelSpin: Float = 0
    private var driftYaw: Float = 0

    private var tuning: Tuning
    private let rig: VehicleRig
    private var biome: Biome
    private var water: WaterSystem?
    private(set) var mode: GameMode

    /// Supplies the scenery near a point. Set by the world once terrain exists.
    var colliderSource: ((SIMD2<Float>) -> [Collider])?

    init(rig: VehicleRig, biome: Biome, water: WaterSystem?, mode: GameMode) {
        self.rig = rig
        self.biome = biome
        self.water = water
        self.mode = mode
        self.tuning = VehicleController.tuning(for: rig.kind, mode: mode)
    }

    func setMode(_ newMode: GameMode) {
        mode = newMode
        tuning = VehicleController.tuning(for: rig.kind, mode: newMode)
    }

    static func tuning(for kind: VehicleKind, mode: GameMode) -> Tuning {
        var t: Tuning
        switch kind {
        case .car:
            t = Tuning(maxSpeed: 21, reverseSpeed: 6, accel: 7.0, brake: 9, drag: 0.55,
                       steerRate: 1.15, bodyLean: 0.055, settle: 7, traction: 14)
        case .quad:
            t = Tuning(maxSpeed: 17, reverseSpeed: 6, accel: 8.5, brake: 10, drag: 0.8,
                       steerRate: 1.5, bodyLean: 0.085, settle: 9, traction: 12)
        case .boat:
            t = Tuning(maxSpeed: 13, reverseSpeed: 4, accel: 3.2, brake: 2.2, drag: 0.35,
                       steerRate: 0.75, bodyLean: 0.11, settle: 3.2, traction: 2.6)
        case .rover:
            t = Tuning(maxSpeed: 11, reverseSpeed: 4, accel: 4.0, brake: 5, drag: 0.35,
                       steerRate: 0.95, bodyLean: 0.05, settle: 5, traction: 11)
        case .spaceship:
            t = Tuning(maxSpeed: 42, reverseSpeed: 8, accel: 10, brake: 8, drag: 0.25,
                       steerRate: 0.85, bodyLean: 0.5, settle: 2.4, traction: 4.5)
        }

        if mode == .speed {
            t.maxSpeed *= 1.85
            t.reverseSpeed *= 1.4
            t.accel *= 2.1
            t.brake *= 1.25
            t.steerRate *= 1.35
            t.drag *= 0.75
            t.bodyLean *= 1.5
            t.traction *= (kind == .boat || kind == .spaceship) ? 0.7 : 0.16
        }
        return t
    }

    var forward: SIMD3<Float> { SIMD3(-sin(heading), 0, -cos(heading)) }
    var right: SIMD3<Float> { SIMD3(-forward.z, 0, forward.x) }
    var speed: Float { simd_dot(velocity, forward) }
    var speedKmh: Float { simd_length(velocity) * 3.6 }
    var normalizedSpeed: Float { min(simd_length(velocity) / tuning.maxSpeed, 1) }
    /// 0 = gripping, 1 = fully sideways. Drives the smoke and the tyre marks.
    var driftAmount: Float { simd_clamp((slip - 1.6) / 7, 0, 1) }

    func setLaunchSpeed(_ v: Float) { velocity = forward * v }

    // MARK: - Step

    /// - Parameters:
    ///   - steer: -1 (left) ... 1 (right)
    ///   - throttle: -1 (brake / reverse) ... 1 (forward)
    func update(dt: Float, steer: Float, throttle: Float, time: Float) {
        let t = tuning

        // Steer first, then re-read the velocity in the new body frame — whatever
        // sideways component is left over is the drift.
        let approxSpeed = simd_length(velocity)
        let grip01 = simd_clamp(approxSpeed / 4.5, 0, 1)
        let goingBackwards = simd_dot(velocity, forward) < -0.1
        heading -= steer * t.steerRate * grip01 * (goingBackwards ? -1 : 1) * dt
        steerAngle += (steer * 0.45 - steerAngle) * min(1, dt * 8)

        let f = forward
        let r = right
        var vf = simd_dot(velocity, f)
        var vl = simd_dot(velocity, r)

        // Longitudinal
        if throttle > 0.02 {
            vf += throttle * t.accel * dt
        } else if throttle < -0.02 {
            vf += throttle * (vf > 0.2 ? t.brake : t.accel * 0.6) * dt
        } else {
            vf -= vf * t.drag * dt * 1.6
            if abs(vf) < 0.05 { vf = 0 }
        }
        vf -= vf * t.drag * dt
        vf = simd_clamp(vf, -t.reverseSpeed, t.maxSpeed)

        // Lateral grip. Braking into a corner lets the back end go.
        var traction = t.traction
        if mode == .speed && throttle < -0.15 { traction *= 0.35 }
        vl -= vl * min(traction * dt, 1)
        vl = simd_clamp(vl, -22, 22)

        slip = abs(vl)
        velocity = f * vf + r * vl
        position += velocity * dt

        resolveCollisions(dt: dt)

        // Ground / surface following
        var groundY: Float = 0
        var nPitch: Float = 0
        var nRoll: Float = 0

        switch rig.kind {
        case .boat:
            let w = water
            let p2 = SIMD2(position.x, position.z)
            groundY = (w?.height(at: p2, time: time) ?? 0) + rig.rideHeight
            let probe: Float = 2.2
            let fwd2 = SIMD2(f.x, f.z), right2 = SIMD2(r.x, r.z)
            let hf = w?.height(at: p2 + fwd2 * probe, time: time) ?? 0
            let hb = w?.height(at: p2 - fwd2 * probe, time: time) ?? 0
            let hl = w?.height(at: p2 - right2 * 1.1, time: time) ?? 0
            let hr = w?.height(at: p2 + right2 * 1.1, time: time) ?? 0
            nPitch = atan2(hf - hb, probe * 2)
            nRoll = atan2(hr - hl, 2.2)

        case .spaceship:
            groundY = sin(time * 0.6) * 0.55 + sin(time * 0.37) * 0.3
            nPitch = 0
            nRoll = 0

        default:
            let p2 = SIMD2(position.x, position.z)
            groundY = biome.height(p2) + rig.rideHeight
            if let level = biome.waterLevel {
                groundY = max(groundY, level + rig.rideHeight * 0.55)
            }
            let probe: Float = 1.8
            let fwd2 = SIMD2(f.x, f.z), right2 = SIMD2(r.x, r.z)
            nPitch = atan2(biome.height(p2 + fwd2 * probe) - biome.height(p2 - fwd2 * probe), probe * 2)
            nRoll = atan2(biome.height(p2 + right2 * probe * 0.6) - biome.height(p2 - right2 * probe * 0.6),
                          probe * 1.2)
        }

        // Smooth everything — this is where the calm comes from.
        visualY += (groundY - visualY) * min(1, dt * tuning.settle)

        var targetPitch = -nPitch
        var targetRoll = nRoll
        if rig.kind == .spaceship {
            targetRoll = -steerAngle * 1.5
            targetPitch = -throttle * 0.06 + sin(time * 0.5) * 0.02
        } else {
            targetRoll += -steerAngle * normalizedSpeed * tuning.bodyLean * 8
            targetRoll += simd_clamp(vl * 0.02, -0.22, 0.22)
            targetPitch += -(throttle * 0.02) * normalizedSpeed
        }
        pitch += (targetPitch - pitch) * min(1, dt * 4.5)
        roll += (targetRoll - roll) * min(1, dt * 4.0)

        // The body points slightly into the slide — the classic drift pose.
        let targetYaw = simd_clamp(-vl * 0.045, -0.5, 0.5)
        driftYaw += (targetYaw - driftYaw) * min(1, dt * 6)

        apply(dt: dt, throttle: throttle)
    }

    // MARK: - Collisions

    private func resolveCollisions(dt: Float) {
        guard let source = colliderSource, rig.collisionRadius > 0 else { return }
        let p2 = SIMD2(position.x, position.z)

        for c in source(p2) {
            let delta = p2 - c.position
            let minDist = c.radius + rig.collisionRadius
            let dist = simd_length(delta)
            guard dist < minDist else { continue }

            let normal = dist > 0.0001 ? delta / dist : SIMD2<Float>(1, 0)
            let push = minDist - dist

            // Move out of the obstacle…
            position.x += normal.x * push
            position.z += normal.y * push

            // …and keep only the part of the motion that runs along it, so you
            // scrape past a trunk instead of stopping dead against it.
            let v2 = SIMD2(velocity.x, velocity.z)
            let into = simd_dot(v2, normal)
            if into < 0 {
                let tangential = v2 - normal * into
                let bounce = normal * (-into * 0.18)
                let slid = tangential * 0.86 + bounce
                velocity.x = slid.x
                velocity.z = slid.y
                pendingImpact = max(pendingImpact, min(-into / 12, 1))
            }
        }
    }

    /// Reads and clears the last bump, so it only ever fires once.
    func consumeImpact() -> Float? {
        guard pendingImpact > 0.06 else { pendingImpact = 0; return nil }
        let value = pendingImpact
        pendingImpact = 0
        return value
    }

    // MARK: - Presentation

    private func apply(dt: Float, throttle: Float) {
        rig.root.position = SCNVector3(position.x, visualY, position.z)
        rig.root.eulerAngles = SCNVector3(0, heading + driftYaw, 0)
        rig.tilt.eulerAngles = SCNVector3(pitch, 0, roll)

        if rig.wheelRadius > 0 {
            let rolling = simd_dot(velocity, forward)
            let spun = rolling + (mode == .speed && throttle > 0 ? driftAmount * 9 : 0)
            wheelSpin -= spun * dt / rig.wheelRadius
            for w in rig.wheelSpinners { w.eulerAngles = SCNVector3(wheelSpin, 0, 0) }
        }
        for h in rig.steerHolders { h.eulerAngles = SCNVector3(0, -steerAngle * 1.2, 0) }

        // Tyre smoke follows how hard we're sliding.
        let intensity = driftAmount
        for e in rig.driftEmitters {
            e.particleSystems?.first?.birthRate = CGFloat(intensity * 130)
        }
    }

    func teleportToSurface(time: Float) {
        switch rig.kind {
        case .boat:
            visualY = (water?.height(at: SIMD2(position.x, position.z), time: time) ?? 0) + rig.rideHeight
        case .spaceship:
            visualY = 0
        default:
            visualY = biome.height(SIMD2(position.x, position.z)) + rig.rideHeight
        }
        apply(dt: 1 / 60, throttle: 0)
    }
}
