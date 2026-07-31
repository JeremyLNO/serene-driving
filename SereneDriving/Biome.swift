import UIKit
import simd

enum VehicleKind {
    case car, quad, boat, rover, spaceship
}

enum PropKind {
    case pineTree, roundTree, bush, rock, cactus, palm, deadWood, snowPine, iceRock
    case moonRock, crystal, asteroid, satellite, buoy, islandPalm, shell, dune
}

enum AmbientParticle {
    case none, pollen, sand, snow, spray, dust, stars
}

func rgb(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

func vec(_ hex: UInt32) -> SIMD3<Float> {
    SIMD3(Float((hex >> 16) & 0xFF) / 255, Float((hex >> 8) & 0xFF) / 255, Float(hex & 0xFF) / 255)
}

struct Biome {
    enum Kind: Int, CaseIterable {
        case forest, desert, beach, ocean, snow, moon, space
    }

    var kind: Kind
    var name: String
    var subtitle: String

    // Sky & light
    var skyZenith: UIColor
    var skyHorizon: UIColor
    var skyLow: UIColor
    var sunColor: UIColor
    var sunIntensity: CGFloat
    var ambientColor: UIColor
    var ambientIntensity: CGFloat
    var sunElevation: Float      // 0 = horizon, 1 = zenith
    var stars: Bool

    // Fog
    var fogColor: UIColor
    var fogStart: CGFloat
    var fogEnd: CGFloat

    // Ground
    let hasTerrain: Bool
    var groundLow: SIMD3<Float>
    var groundHigh: SIMD3<Float>
    var groundSlope: SIMD3<Float>

    // Water
    let waterLevel: Float?
    var waterColor: UIColor
    var waterOpacity: CGFloat

    let vehicle: VehicleKind
    let props: [PropKind]
    var propDensity: Int          // props per chunk
    var particle: AmbientParticle

    /// Soft ground keeps a record of where you drove.
    var leavesTracks: Bool {
        switch kind {
        case .desert, .beach, .snow, .moon: return true
        case .forest, .ocean, .space: return false
        }
    }

    // MARK: - Terrain

    func height(_ p: SIMD2<Float>) -> Float {
        switch kind {
        case .forest:
            return Noise.fbm(p * 0.0090, octaves: 4) * 6.0
                 + Noise.fbm(p * 0.0380, octaves: 3) * 1.0
        case .desert:
            return Noise.ridged(p * 0.0075, octaves: 3) * 11.0 - 3.0
                 + Noise.fbm(p * 0.052, octaves: 2) * 0.5
        case .beach:
            // Mostly sand, with lagoons and inlets cut into it.
            return Noise.fbm(p * 0.0072, octaves: 4) * 7.0 + 3.2
                 + Noise.fbm(p * 0.045, octaves: 2) * 0.4
        case .ocean:
            // Mostly deep water, with the occasional island to steer around.
            let r = Noise.ridged(p * 0.0050, octaves: 3)
            let island = powf(max(r - 0.42, 0) / 0.58, 2.4)
            return -15.0 + island * 34.0 + Noise.fbm(p * 0.02, octaves: 2) * 0.8
        case .snow:
            return Noise.fbm(p * 0.0085, octaves: 4) * 6.5
                 + Noise.ridged(p * 0.0035, octaves: 2) * 4.0 - 1.5
        case .moon:
            return Noise.fbm(p * 0.0110, octaves: 3) * 4.0
                 - Noise.ridged(p * 0.0190, octaves: 2) * 3.2
        case .space:
            return 0
        }
    }

    /// Colour of the ground at a point, before lighting.
    func groundColor(height h: Float, slope: Float, jitter: Float) -> SIMD3<Float> {
        var t = simd_clamp((h + 6) / 16, 0, 1)
        t = simd_clamp(t + jitter * 0.18, 0, 1)
        var c = simd_mix(groundLow, groundHigh, SIMD3(repeating: t))
        let s = simd_clamp((slope - 0.34) * 2.6, 0, 1)
        c = simd_mix(c, groundSlope, SIMD3(repeating: s))
        return c * (0.94 + jitter * 0.12)
    }

    // MARK: - Catalogue

    static let all: [Biome] = [
        Biome(kind: .forest,
              name: "Whispering Forest",
              subtitle: "take your time",
              skyZenith: rgb(0x7FB6E0), skyHorizon: rgb(0xDCEFF3), skyLow: rgb(0xB9D6B4),
              sunColor: rgb(0xFFF3DC), sunIntensity: 1050, ambientColor: rgb(0xBBD7E8), ambientIntensity: 480,
              sunElevation: 0.55, stars: false,
              fogColor: rgb(0xCFE4E4), fogStart: 70, fogEnd: 225,
              hasTerrain: true,
              groundLow: vec(0x4E7A4A), groundHigh: vec(0x86A85F), groundSlope: vec(0x8B7C63),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .car,
              props: [.pineTree, .roundTree, .roundTree, .bush, .rock, .deadWood],
              propDensity: 16, particle: .pollen),

        Biome(kind: .desert,
              name: "Amber Dunes",
              subtitle: "nothing but horizon",
              skyZenith: rgb(0x6FA8D6), skyHorizon: rgb(0xFBE0BA), skyLow: rgb(0xE7C79A),
              sunColor: rgb(0xFFE9C4), sunIntensity: 1250, ambientColor: rgb(0xE8CBA4), ambientIntensity: 460,
              sunElevation: 0.42, stars: false,
              fogColor: rgb(0xF2DDC0), fogStart: 85, fogEnd: 235,
              hasTerrain: true,
              groundLow: vec(0xC99C63), groundHigh: vec(0xE9CF9C), groundSlope: vec(0xB08558),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .quad,
              props: [.cactus, .rock, .deadWood, .bush, .dune],
              propDensity: 8, particle: .sand),

        Biome(kind: .beach,
              name: "Sunlit Shore",
              subtitle: "salt in the air",
              skyZenith: rgb(0x74BEE4), skyHorizon: rgb(0xE8F6F7), skyLow: rgb(0x9AD9DA),
              sunColor: rgb(0xFFF6E2), sunIntensity: 1150, ambientColor: rgb(0xC4E6EE), ambientIntensity: 520,
              sunElevation: 0.5, stars: false,
              fogColor: rgb(0xDDF0F1), fogStart: 85, fogEnd: 235,
              hasTerrain: true,
              groundLow: vec(0xD6BE8E), groundHigh: vec(0xEFE0B6), groundSlope: vec(0xC4AF87),
              waterLevel: 0, waterColor: rgb(0x53BCC4), waterOpacity: 0.80,
              vehicle: .quad,
              props: [.palm, .islandPalm, .bush, .rock, .shell],
              propDensity: 11, particle: .spray),

        Biome(kind: .ocean,
              name: "Open Sea",
              subtitle: "drift a while",
              skyZenith: rgb(0x5DA6D8), skyHorizon: rgb(0xDCEEF6), skyLow: rgb(0x7EC0D8),
              sunColor: rgb(0xFFF4E4), sunIntensity: 1080, ambientColor: rgb(0xB6DDEE), ambientIntensity: 540,
              sunElevation: 0.46, stars: false,
              fogColor: rgb(0xD5EAF3), fogStart: 90, fogEnd: 245,
              hasTerrain: true,
              groundLow: vec(0xD8C79A), groundHigh: vec(0x93A86E), groundSlope: vec(0x9E9276),
              waterLevel: 0, waterColor: rgb(0x2E8CAE), waterOpacity: 0.93,
              vehicle: .boat,
              props: [.islandPalm, .rock, .buoy, .palm],
              propDensity: 7, particle: .spray),

        Biome(kind: .snow,
              name: "Quiet Snowfield",
              subtitle: "everything is soft",
              skyZenith: rgb(0x9CB6D2), skyHorizon: rgb(0xF0E6EA), skyLow: rgb(0xDCE4EE),
              sunColor: rgb(0xFFEFE8), sunIntensity: 900, ambientColor: rgb(0xCBD9EA), ambientIntensity: 640,
              sunElevation: 0.3, stars: false,
              fogColor: rgb(0xE6ECF3), fogStart: 55, fogEnd: 200,
              hasTerrain: true,
              groundLow: vec(0xDCE6F0), groundHigh: vec(0xFAFCFF), groundSlope: vec(0xA9B6C6),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .car,
              props: [.snowPine, .snowPine, .iceRock, .rock, .deadWood],
              propDensity: 13, particle: .snow),

        Biome(kind: .moon,
              name: "Moon Basin",
              subtitle: "gravity forgot you",
              skyZenith: rgb(0x05060E), skyHorizon: rgb(0x161A2A), skyLow: rgb(0x0A0B12),
              sunColor: rgb(0xFFFFFF), sunIntensity: 1350, ambientColor: rgb(0x38415E), ambientIntensity: 260,
              sunElevation: 0.35, stars: true,
              fogColor: rgb(0x1A1E2C), fogStart: 110, fogEnd: 240,
              hasTerrain: true,
              groundLow: vec(0x6E6E76), groundHigh: vec(0xB4B4BC), groundSlope: vec(0x54545C),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .rover,
              props: [.moonRock, .moonRock, .rock, .crystal],
              propDensity: 10, particle: .dust),

        Biome(kind: .space,
              name: "Deep Space",
              subtitle: "no up, no down",
              skyZenith: rgb(0x05030E), skyHorizon: rgb(0x241B45), skyLow: rgb(0x0B0718),
              sunColor: rgb(0xE6E1FF), sunIntensity: 900, ambientColor: rgb(0x4A3E7A), ambientIntensity: 380,
              sunElevation: 0.6, stars: true,
              fogColor: rgb(0x120C24), fogStart: 150, fogEnd: 420,
              hasTerrain: false,
              groundLow: .zero, groundHigh: .zero, groundSlope: .zero,
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .spaceship,
              props: [.asteroid, .asteroid, .crystal, .satellite],
              propDensity: 9, particle: .stars),
    ]
}
