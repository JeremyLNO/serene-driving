import UIKit
import simd

/// When you arrive somewhere, you also arrive at a time of day and into weather.
/// A mood grades the biome's palette rather than duplicating it, so one set of
/// worlds covers a lot of different skies.

enum TimeOfDay: String, CaseIterable {
    case dawn, day, dusk, night

    var phrase: String {
        switch self {
        case .dawn:  return "first light"
        case .day:   return ""
        case .dusk:  return "the light goes gold"
        case .night: return "everything asleep"
        }
    }
}

enum Weather: String, CaseIterable {
    case clear, mist, rain, aurora

    var phrase: String {
        switch self {
        case .clear:  return ""
        case .mist:   return "the air is thick"
        case .rain:   return "soft rain"
        case .aurora: return "the sky is awake"
        }
    }
}

struct WorldMood {
    var time: TimeOfDay = .day
    var weather: Weather = .clear

    /// What to print under the world's name.
    func subtitle(default fallback: String) -> String {
        if !weather.phrase.isEmpty { return weather.phrase }
        if !time.phrase.isEmpty { return time.phrase }
        return fallback
    }

    static func random(for biome: Biome, using rng: inout SeededRandom) -> WorldMood {
        // The moon and deep space have their own permanent night.
        guard !biome.stars else { return WorldMood() }

        let roll = rng.next()
        let time: TimeOfDay
        switch roll {
        case ..<0.42: time = .day
        case ..<0.62: time = .dawn
        case ..<0.82: time = .dusk
        default:      time = .night
        }

        var options: [Weather] = [.clear, .clear, .clear, .mist]
        switch biome.kind {
        case .desert:
            options = [.clear, .clear, .clear, .clear, .mist]
        case .forest, .snow:
            options += [.rain]
            if time == .night { options += [.aurora, .aurora] }
        case .beach, .ocean:
            options += [.rain, .mist]
        case .moon, .space:
            options = [.clear]
        }

        let weather = options[Int(rng.next() * Float(options.count - 1) + 0.5)]
        return WorldMood(time: time, weather: weather)
    }
}

// MARK: - Colour helpers

func blendColor(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    let k = min(max(t, 0), 1)
    return UIColor(red: ar + (br - ar) * k,
                   green: ag + (bg - ag) * k,
                   blue: ab + (bb - ab) * k,
                   alpha: 1)
}

private func blendVec(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
    simd_mix(a, b, SIMD3(repeating: simd_clamp(t, 0, 1)))
}

extension Biome {

    /// A copy of this world tinted for the given time of day and weather.
    func graded(_ mood: WorldMood) -> Biome {
        var b = self
        guard !stars else { return b }      // moon / space are already night

        switch mood.time {
        case .day:
            break

        case .dawn:
            b.sunElevation = 0.11
            b.sunColor = blendColor(sunColor, rgb(0xFFC49B), 0.78)
            b.sunIntensity *= 0.70
            b.skyZenith = blendColor(skyZenith, rgb(0x2F4C7C), 0.58)
            b.skyHorizon = blendColor(skyHorizon, rgb(0xF8CBA6), 0.72)
            b.skyLow = blendColor(skyLow, rgb(0xDFA98D), 0.55)
            b.ambientColor = blendColor(ambientColor, rgb(0x5C71A0), 0.62)
            b.ambientIntensity *= 0.78
            b.fogColor = blendColor(fogColor, rgb(0xE9C6B0), 0.62)
            b.groundLow = blendVec(groundLow, vec(0x6E6E90), 0.22)
            b.groundHigh = blendVec(groundHigh, vec(0xC9A896), 0.22)
            b.waterColor = blendColor(waterColor, rgb(0x6E7FA8), 0.35)

        case .dusk:
            b.sunElevation = 0.075
            b.sunColor = blendColor(sunColor, rgb(0xFFA469), 0.82)
            b.sunIntensity *= 0.66
            b.skyZenith = blendColor(skyZenith, rgb(0x2A2C63), 0.66)
            b.skyHorizon = blendColor(skyHorizon, rgb(0xF29E70), 0.76)
            b.skyLow = blendColor(skyLow, rgb(0xC87A63), 0.58)
            b.ambientColor = blendColor(ambientColor, rgb(0x6A5A90), 0.66)
            b.ambientIntensity *= 0.74
            b.fogColor = blendColor(fogColor, rgb(0xE2AC93), 0.66)
            b.groundLow = blendVec(groundLow, vec(0x6A5F7E), 0.26)
            b.groundHigh = blendVec(groundHigh, vec(0xC9977E), 0.26)
            b.waterColor = blendColor(waterColor, rgb(0x7A6EA0), 0.38)

        case .night:
            b.stars = true
            b.sunElevation = 0.34
            b.sunColor = rgb(0xC2D6FF)
            b.sunIntensity *= 0.22
            b.skyZenith = rgb(0x080D1E)
            b.skyHorizon = blendColor(skyHorizon, rgb(0x1C2946), 0.86)
            b.skyLow = rgb(0x101728)
            b.ambientColor = rgb(0x33456E)
            b.ambientIntensity *= 0.78
            b.fogColor = rgb(0x151E36)
            b.fogEnd *= 0.86
            b.groundLow = blendVec(groundLow, vec(0x1E2740), 0.62)
            b.groundHigh = blendVec(groundHigh, vec(0x36436A), 0.58)
            b.groundSlope = blendVec(groundSlope, vec(0x222B44), 0.6)
            b.waterColor = blendColor(waterColor, rgb(0x16305A), 0.62)
        }

        switch mood.weather {
        case .clear:
            break

        case .mist:
            b.fogStart *= 0.40
            b.fogEnd *= 0.46
            b.sunIntensity *= 0.52
            b.ambientIntensity *= 1.30
            b.fogColor = blendColor(b.fogColor, .white, 0.22)
            b.skyHorizon = blendColor(b.skyHorizon, b.fogColor, 0.55)
            b.skyLow = blendColor(b.skyLow, b.fogColor, 0.6)

        case .rain:
            b.fogStart *= 0.62
            b.fogEnd *= 0.66
            b.sunIntensity *= 0.38
            b.ambientIntensity *= 1.12
            b.ambientColor = blendColor(b.ambientColor, rgb(0x8894A8), 0.5)
            b.fogColor = blendColor(b.fogColor, rgb(0x8E9AA8), 0.5)
            b.skyZenith = blendColor(b.skyZenith, rgb(0x596879), 0.55)
            b.skyHorizon = blendColor(b.skyHorizon, rgb(0x93A0AE), 0.6)
            b.skyLow = blendColor(b.skyLow, rgb(0x7E8B99), 0.55)
            // wet ground reads darker
            b.groundLow *= 0.80
            b.groundHigh *= 0.80
            b.groundSlope *= 0.82

        case .aurora:
            b.ambientColor = blendColor(b.ambientColor, rgb(0x3FA98C), 0.45)
            b.ambientIntensity *= 1.35
            b.fogColor = blendColor(b.fogColor, rgb(0x1E4A48), 0.35)
            b.groundHigh = blendVec(b.groundHigh, vec(0x3E6E68), 0.25)
        }

        b.subtitle = mood.subtitle(default: subtitle)
        return b
    }
}
