import SceneKit

enum ParticleFactory {

    /// Smoke thrown off a sliding tyre. Birth rate is driven every frame by the
    /// controller, so it only appears when the vehicle is actually sideways.
    static func tyreSmoke(tint: UIColor) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = SkyFactory.softDot
        ps.birthRate = 0
        ps.loops = true
        ps.emitterShape = SCNSphere(radius: 0.16)
        ps.birthLocation = .volume
        ps.particleLifeSpan = 1.5
        ps.particleLifeSpanVariation = 0.6
        ps.particleSize = 0.26
        ps.particleSizeVariation = 0.14
        ps.particleColor = tint
        ps.particleColorVariation = SCNVector4(0, 0, 0.05, 0.2)
        ps.particleVelocity = 1.6
        ps.particleVelocityVariation = 1.1
        ps.emittingDirection = SCNVector3(0, 0.4, 1)
        ps.spreadingAngle = 75
        ps.acceleration = SCNVector3(0, 0.9, 0)
        ps.isAffectedByGravity = false
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.sortingMode = .distance
        ps.particleAngularVelocity = 40
        ps.particleAngularVelocityVariation = 60

        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 0.34, 0.20, 0.0]
        fade.keyTimes = [0.0, 0.12, 0.45, 1.0]
        fade.duration = 1
        let grow = CAKeyframeAnimation()
        grow.values = [0.35, 1.0, 1.9]
        grow.keyTimes = [0.0, 0.4, 1.0]
        grow.duration = 1
        ps.propertyControllers = [
            .opacity: SCNParticlePropertyController(animation: fade),
            .size: SCNParticlePropertyController(animation: grow),
        ]
        return ps
    }

    /// Rain streaks and drifting mist — layered on top of the biome's own motes.
    static func weatherSystem(for weather: Weather) -> SCNParticleSystem? {
        switch weather {
        case .clear, .aurora:
            return nil

        case .rain:
            let ps = SCNParticleSystem()
            ps.particleImage = SkyFactory.softDot
            ps.emitterShape = SCNBox(width: 80, height: 4, length: 80, chamferRadius: 0)
            ps.birthLocation = .volume
            ps.birthDirection = .constant
            ps.isAffectedByGravity = false
            ps.loops = true
            ps.birthRate = 900
            ps.particleLifeSpan = 1.5
            ps.particleLifeSpanVariation = 0.4
            ps.particleSize = 0.035
            ps.particleSizeVariation = 0.02
            ps.stretchFactor = 0.55
            ps.particleColor = rgb(0xC8D8E8).withAlphaComponent(0.55)
            ps.particleVelocity = 26
            ps.particleVelocityVariation = 5
            ps.emittingDirection = SCNVector3(0.10, -1, 0.05)
            ps.spreadingAngle = 4
            ps.blendMode = .alpha
            ps.isLightingEnabled = false
            ps.sortingMode = .none
            return ps

        case .mist:
            let ps = SCNParticleSystem()
            ps.particleImage = SkyFactory.softDot
            ps.emitterShape = SCNBox(width: 110, height: 12, length: 110, chamferRadius: 0)
            ps.birthLocation = .volume
            ps.isAffectedByGravity = false
            ps.loops = true
            ps.birthRate = 42
            ps.particleLifeSpan = 16
            ps.particleLifeSpanVariation = 5
            ps.particleSize = 3.0
            ps.particleSizeVariation = 1.6
            ps.particleColor = UIColor.white.withAlphaComponent(0.035)
            ps.particleVelocity = 0.7
            ps.particleVelocityVariation = 0.5
            ps.emittingDirection = SCNVector3(1, 0.05, 0.3)
            ps.spreadingAngle = 40
            ps.blendMode = .alpha
            ps.isLightingEnabled = false
            ps.sortingMode = .none
            return ps
        }
    }

    static func system(for kind: AmbientParticle) -> SCNParticleSystem? {
        guard kind != .none else { return nil }
        let ps = SCNParticleSystem()
        ps.particleImage = SkyFactory.softDot
        ps.emitterShape = SCNBox(width: 90, height: 16, length: 90, chamferRadius: 0)
        ps.birthLocation = .volume
        ps.birthDirection = .constant
        ps.isAffectedByGravity = false
        ps.loops = true
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        ps.sortingMode = .none

        switch kind {
        case .pollen:
            ps.birthRate = 70
            ps.particleLifeSpan = 9
            ps.particleLifeSpanVariation = 3
            ps.particleSize = 0.055
            ps.particleSizeVariation = 0.04
            ps.particleColor = rgb(0xF6E9BE).withAlphaComponent(0.75)
            ps.particleColorVariation = SCNVector4(0.05, 0.05, 0.1, 0.4)
            ps.particleVelocity = 0.5
            ps.particleVelocityVariation = 0.5
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 180
            ps.particleAngularVelocity = 12

        case .snow:
            ps.particleImage = SkyFactory.flake
            ps.blendMode = .alpha
            ps.birthRate = 340
            ps.particleLifeSpan = 10
            ps.particleLifeSpanVariation = 3
            ps.particleSize = 0.075
            ps.particleSizeVariation = 0.05
            ps.particleColor = .white
            ps.particleVelocity = 1.6
            ps.particleVelocityVariation = 0.8
            ps.emittingDirection = SCNVector3(0.15, -1, 0.05)
            ps.spreadingAngle = 22
            ps.acceleration = SCNVector3(0.2, -0.15, 0)

        case .sand:
            ps.birthRate = 190
            ps.particleLifeSpan = 6
            ps.particleLifeSpanVariation = 2
            ps.particleSize = 0.05
            ps.particleSizeVariation = 0.03
            ps.particleColor = rgb(0xE9D3AC)
            ps.particleVelocity = 5
            ps.particleVelocityVariation = 2.5
            ps.emittingDirection = SCNVector3(1, 0.08, 0.35)
            ps.spreadingAngle = 16

        case .spray:
            ps.birthRate = 110
            ps.particleLifeSpan = 7
            ps.particleLifeSpanVariation = 2
            ps.particleSize = 0.06
            ps.particleSizeVariation = 0.04
            ps.particleColor = rgb(0xEAF8FF)
            ps.particleVelocity = 1.2
            ps.particleVelocityVariation = 1.0
            ps.emittingDirection = SCNVector3(0.4, 0.6, 0.2)
            ps.spreadingAngle = 120

        case .dust:
            ps.birthRate = 60
            ps.particleLifeSpan = 12
            ps.particleLifeSpanVariation = 4
            ps.particleSize = 0.035
            ps.particleColor = rgb(0x9AA4BC)
            ps.particleVelocity = 0.35
            ps.particleVelocityVariation = 0.3
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 180

        case .stars:
            ps.birthRate = 95
            ps.particleLifeSpan = 14
            ps.particleLifeSpanVariation = 5
            ps.particleSize = 0.05
            ps.particleSizeVariation = 0.035
            ps.particleColor = rgb(0xEFEAFF)
            ps.particleColorVariation = SCNVector4(0.15, 0.1, 0.2, 0.4)
            ps.particleVelocity = 0.2
            ps.particleVelocityVariation = 0.2
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 180
            ps.emitterShape = SCNBox(width: 120, height: 90, length: 120, chamferRadius: 0)

        case .ash:
            ps.blendMode = .alpha
            ps.birthRate = 150
            ps.particleLifeSpan = 11
            ps.particleLifeSpanVariation = 4
            ps.particleSize = 0.055
            ps.particleSizeVariation = 0.04
            ps.particleColor = rgb(0x6A5E5A).withAlphaComponent(0.75)
            ps.particleVelocity = 1.1
            ps.particleVelocityVariation = 0.8
            ps.emittingDirection = SCNVector3(0.3, 1, 0.1)
            ps.spreadingAngle = 65
            ps.acceleration = SCNVector3(0.15, 0.05, 0)

        case .leaves:
            ps.blendMode = .alpha
            ps.birthRate = 90
            ps.particleLifeSpan = 12
            ps.particleLifeSpanVariation = 4
            ps.particleSize = 0.11
            ps.particleSizeVariation = 0.06
            ps.particleColor = rgb(0xD08A3A)
            ps.particleColorVariation = SCNVector4(0.10, 0.16, 0.06, 0.25)
            ps.particleVelocity = 1.5
            ps.particleVelocityVariation = 1.0
            ps.emittingDirection = SCNVector3(0.35, -1, 0.15)
            ps.spreadingAngle = 55
            ps.acceleration = SCNVector3(0.4, -0.1, 0.15)
            ps.particleAngularVelocity = 130
            ps.particleAngularVelocityVariation = 160

        case .spores:
            ps.birthRate = 130
            ps.particleLifeSpan = 14
            ps.particleLifeSpanVariation = 5
            ps.particleSize = 0.07
            ps.particleSizeVariation = 0.05
            ps.particleColor = rgb(0x7FE8D0)
            ps.particleColorVariation = SCNVector4(0.25, 0.12, 0.3, 0.35)
            ps.particleVelocity = 0.45
            ps.particleVelocityVariation = 0.4
            ps.emittingDirection = SCNVector3(0, 1, 0)
            ps.spreadingAngle = 180
            ps.particleAngularVelocity = 20

        case .none:
            return nil
        }
        return ps
    }
}
