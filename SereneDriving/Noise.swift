import simd
import Foundation

/// Deterministic value noise. Everything in the world is derived from it,
/// so the same coordinates always rebuild the same landscape.
enum Noise {

    @inline(__always)
    static func hash2(_ x: Int32, _ y: Int32) -> Float {
        var h = UInt32(bitPattern: x &* 374_761_393) &+ UInt32(bitPattern: y &* 668_265_263)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h = h ^ (h >> 16)
        return Float(h) / Float(UInt32.max)
    }

    /// Value noise in -1...1
    @inline(__always)
    static func value(_ p: SIMD2<Float>) -> Float {
        let i = floor(p)
        let f = p - i
        let u = f * f * (3 - 2 * f)
        let ix = Int32(i.x), iy = Int32(i.y)
        let a = hash2(ix, iy)
        let b = hash2(ix &+ 1, iy)
        let c = hash2(ix, iy &+ 1)
        let d = hash2(ix &+ 1, iy &+ 1)
        let ab = a + (b - a) * u.x
        let cd = c + (d - c) * u.x
        return (ab + (cd - ab) * u.y) * 2 - 1
    }

    static func fbm(_ p: SIMD2<Float>, octaves: Int = 4, lacunarity: Float = 2.03, gain: Float = 0.5) -> Float {
        var amp: Float = 1, freq: Float = 1, sum: Float = 0, norm: Float = 0
        for _ in 0..<octaves {
            sum += value(p * freq) * amp
            norm += amp
            amp *= gain
            freq *= lacunarity
        }
        return sum / max(norm, 0.0001)
    }

    /// Ridged noise — good for dunes and mountain spines.
    static func ridged(_ p: SIMD2<Float>, octaves: Int = 3) -> Float {
        var amp: Float = 1, freq: Float = 1, sum: Float = 0, norm: Float = 0
        for _ in 0..<octaves {
            let n = 1 - abs(value(p * freq))
            sum += n * n * amp
            norm += amp
            amp *= 0.5
            freq *= 2.07
        }
        return sum / max(norm, 0.0001)
    }
}

/// Tiny deterministic generator used to scatter props without ever repeating a pattern.
struct SeededRandom {
    private var state: UInt64

    init(_ seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407 }

    mutating func next() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let x = UInt32(truncatingIfNeeded: state >> 32)
        return Float(x) / Float(UInt32.max)
    }

    mutating func range(_ lo: Float, _ hi: Float) -> Float { lo + (hi - lo) * next() }

    mutating func chance(_ p: Float) -> Bool { next() < p }
}
