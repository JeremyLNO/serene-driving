import UIKit
import simd

enum VehicleKind {
    case car, quad, boat, rover, spaceship
}

enum PropKind {
    case pineTree, roundTree, bush, rock, cactus, palm, deadWood, snowPine, iceRock
    case moonRock, crystal, asteroid, satellite, buoy, islandPalm, shell, dune
    case autumnTree, mesa, canyonSpire, saltRidge, basaltSpire, lavaRock
    case glowMushroom, alienPod
}

enum AmbientParticle {
    case none, pollen, sand, snow, spray, dust, stars, ash, leaves, spores
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
        case forest, autumn, desert, canyon, beach, ocean, saltflats, snow, volcano, moon, alien, space
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
        case .desert, .beach, .snow, .moon, .canyon, .saltflats, .volcano: return true
        case .forest, .autumn, .ocean, .alien, .space: return false
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
            // Sand with real lagoons cut into it — about a fifth of the shore is
            // water, which is what makes it a shore rather than a dune field.
            return Noise.fbm(p * 0.0072, octaves: 4) * 7.0 + 1.6
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
        case .autumn:
            return Noise.fbm(p * 0.0095, octaves: 4) * 6.5
                 + Noise.fbm(p * 0.040, octaves: 3) * 1.1

        case .canyon:
            // Terraced mesas. The steps are eased rather than square: a hard
            // quantise makes vertical cliffs that nothing can drive up and that
            // the chase camera ends up buried inside.
            let n = Noise.fbm(p * 0.0060, octaves: 4)
            let steps: Float = 3.0
            let scaled = n * steps
            let base = scaled.rounded(.down)
            let frac = scaled - base
            let t = simd_clamp((frac - 0.62) / 0.38, 0, 1)
            let ramp = t * t * (3 - 2 * t)
            return (base + ramp) / steps * 17.0 + Noise.fbm(p * 0.045, octaves: 2) * 0.8

        case .saltflats:
            // Almost dead flat — the point is the horizon and the speed.
            return Noise.fbm(p * 0.0045, octaves: 3) * 1.1
                 + Noise.fbm(p * 0.060, octaves: 2) * 0.12

        case .volcano:
            return Noise.ridged(p * 0.0070, octaves: 3) * 9.0 - 2.5
                 + Noise.fbm(p * 0.0180, octaves: 3) * 2.6

        case .alien:
            return Noise.fbm(p * 0.0090, octaves: 4) * 7.0
                 + Noise.ridged(p * 0.0150, octaves: 2) * 3.4 - 1.5

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

        Biome(kind: .autumn,
              name: "Golden Woods",
              subtitle: "the year turning",
              skyZenith: rgb(0x6FA8D8), skyHorizon: rgb(0xF7E3C2), skyLow: rgb(0xD9BE92),
              sunColor: rgb(0xFFEAC4), sunIntensity: 1000, ambientColor: rgb(0xCBB89C), ambientIntensity: 470,
              sunElevation: 0.44, stars: false,
              fogColor: rgb(0xE9D7BC), fogStart: 65, fogEnd: 220,
              hasTerrain: true,
              groundLow: vec(0x7A6038), groundHigh: vec(0xB78C48), groundSlope: vec(0x8A7358),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .car,
              props: [.autumnTree, .autumnTree, .roundTree, .bush, .rock, .deadWood],
              propDensity: 16, particle: .leaves),

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

        Biome(kind: .canyon,
              name: "Red Canyon",
              subtitle: "wind and stone",
              skyZenith: rgb(0x5F9AD0), skyHorizon: rgb(0xF1CCA6), skyLow: rgb(0xD9A279),
              sunColor: rgb(0xFFE3B8), sunIntensity: 1200, ambientColor: rgb(0xE0B896), ambientIntensity: 440,
              sunElevation: 0.50, stars: false,
              fogColor: rgb(0xEBC9A8), fogStart: 80, fogEnd: 235,
              hasTerrain: true,
              groundLow: vec(0xA85C3E), groundHigh: vec(0xD9905E), groundSlope: vec(0x8E4A32),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .quad,
              props: [.mesa, .canyonSpire, .canyonSpire, .rock, .bush, .deadWood],
              propDensity: 6, particle: .sand),

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

        Biome(kind: .saltflats,
              name: "Salt Flats",
              subtitle: "nothing in the way",
              skyZenith: rgb(0x77B4E4), skyHorizon: rgb(0xEFF4F8), skyLow: rgb(0xDCE6EC),
              sunColor: rgb(0xFFFDF6), sunIntensity: 1150, ambientColor: rgb(0xD8E4EE), ambientIntensity: 620,
              sunElevation: 0.60, stars: false,
              fogColor: rgb(0xE9F0F5), fogStart: 100, fogEnd: 260,
              hasTerrain: true,
              groundLow: vec(0xD4DBE0), groundHigh: vec(0xF5F8FA), groundSlope: vec(0xB4BCC4),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .car,
              props: [.saltRidge, .saltRidge, .rock],
              propDensity: 5, particle: .dust),

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

        Biome(kind: .volcano,
              name: "Ash Fields",
              subtitle: "the ground remembers",
              skyZenith: rgb(0x2A1E28), skyHorizon: rgb(0x8E4A38), skyLow: rgb(0x4A2A26),
              sunColor: rgb(0xFFB07A), sunIntensity: 820, ambientColor: rgb(0x7A4A44), ambientIntensity: 400,
              sunElevation: 0.20, stars: false,
              fogColor: rgb(0x5C3832), fogStart: 55, fogEnd: 190,
              hasTerrain: true,
              groundLow: vec(0x2E2A2E), groundHigh: vec(0x5A5050), groundSlope: vec(0x1E1A1C),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .quad,
              props: [.basaltSpire, .lavaRock, .lavaRock, .rock, .deadWood],
              propDensity: 12, particle: .ash),

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

        Biome(kind: .alien,
              name: "Lumen Valley",
              subtitle: "nothing here has a name",
              skyZenith: rgb(0x160D30), skyHorizon: rgb(0x4A2A6E), skyLow: rgb(0x241846),
              sunColor: rgb(0xC9A8FF), sunIntensity: 700, ambientColor: rgb(0x5C4090), ambientIntensity: 430,
              sunElevation: 0.35, stars: true,
              fogColor: rgb(0x2A1A4A), fogStart: 70, fogEnd: 215,
              hasTerrain: true,
              groundLow: vec(0x2E2A5A), groundHigh: vec(0x4E4A8E), groundSlope: vec(0x241E46),
              waterLevel: nil, waterColor: .clear, waterOpacity: 0,
              vehicle: .rover,
              props: [.glowMushroom, .glowMushroom, .alienPod, .crystal, .rock],
              propDensity: 13, particle: .spores),

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
