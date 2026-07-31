import SceneKit
import simd

/// Tyre marks pressed into soft ground. Both ribbons live in one geometry that is
/// rebuilt whenever a new sample is laid down, so the whole trail is a single draw.
final class TrackSystem {

    let node = SCNNode()

    private struct Sample {
        var leftOuter: SIMD3<Float>
        var leftInner: SIMD3<Float>
        var rightInner: SIMD3<Float>
        var rightOuter: SIMD3<Float>
        var shade: Float
    }

    private var samples: [Sample] = []
    private let maxSamples = 165
    private let spacing: Float = 1.1
    /// Number of samples at the tail that dissolve back into the ground.
    private let fadeSamples: Float = 14
    private var lastSample: SIMD2<Float>?

    private let biome: Biome
    private let color: SIMD3<Float>

    init(biome: Biome) {
        self.biome = biome
        // A shade darker than the ground it's pressed into.
        let base = simd_mix(biome.groundLow, biome.groundHigh, SIMD3(repeating: 0.5))
        self.color = simd_clamp(base * 0.68, SIMD3(repeating: 0), SIMD3(repeating: 1))
        node.castsShadow = false
        node.renderingOrder = 5
    }

    func reset() {
        samples.removeAll()
        lastSample = nil
        node.geometry = nil
    }

    /// - Parameter drift: 0...1, widens and darkens the mark while sliding.
    func update(position: SIMD3<Float>, heading: Float, halfWidth: Float,
                width: Float, drift: Float, airborne: Bool) {
        guard biome.leavesTracks, halfWidth > 0, !airborne else { return }

        let p2 = SIMD2(position.x, position.z)
        if let last = lastSample, simd_distance(last, p2) < spacing { return }
        lastSample = p2

        let right = SIMD2(cos(heading), -sin(heading))
        let w = width * (0.26 + drift * 0.24)

        func point(_ offset: Float) -> SIMD3<Float> {
            let xz = p2 + right * offset
            let y = biome.height(xz) + 0.055
            return SIMD3(xz.x, y, xz.y)
        }

        samples.append(Sample(leftOuter: point(-halfWidth - w),
                              leftInner: point(-halfWidth + w),
                              rightInner: point(halfWidth - w),
                              rightOuter: point(halfWidth + w),
                              shade: 0.82 - drift * 0.22))

        if samples.count > maxSamples { samples.removeFirst(samples.count - maxSamples) }
        rebuild()
    }

    private func rebuild() {
        guard samples.count > 1 else { node.geometry = nil; return }

        var positions = [SIMD3<Float>]()
        var colors = [SIMD3<Float>]()
        positions.reserveCapacity((samples.count - 1) * 12)

        for i in 0..<(samples.count - 1) {
            let a = samples[i], b = samples[i + 1]
            // Only the oldest handful of samples dissolve back into the ground,
            // so a fresh trail is dark straight away.
            let strength = simd_smoothstep(0, 1, min(Float(i) / fadeSamples, 1))
            let tint = simd_mix(biome.groundHigh, color * a.shade, SIMD3(repeating: strength))

            func quad(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>, _ p3: SIMD3<Float>) {
                positions.append(p0); positions.append(p2); positions.append(p1)
                positions.append(p1); positions.append(p2); positions.append(p3)
                for _ in 0..<6 { colors.append(tint) }
            }
            quad(a.leftOuter, a.leftInner, b.leftOuter, b.leftInner)
            quad(a.rightInner, a.rightOuter, b.rightInner, b.rightOuter)
        }

        let geo = GeometryKit.flatShaded(positions: positions, colors: colors)
        if let m = geo.firstMaterial {
            m.isDoubleSided = true
            m.writesToDepthBuffer = false
            m.blendMode = .alpha
            m.transparency = 0.6
        }
        node.geometry = geo
    }
}

private func simd_smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = simd_clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
}
