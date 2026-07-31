import SceneKit
import simd

/// Water in two layers: a big flat plane that reaches the horizon, and a faceted
/// wave mesh around the player that is rebuilt as it moves. The visible waves are
/// generated on the CPU so the boat floats on exactly what you can see.
final class WaterSystem {

    let node = SCNNode()

    private let farNode = SCNNode()
    private let nearNode = SCNNode()
    private let level: Float
    private let tint: SIMD3<Float>
    private let surfaceMaterial: SCNMaterial

    /// Wave mesh extent and resolution around the player.
    private let cells = 36
    private let span: Float = 190
    private var cellSize: Float { span / Float(cells) }

    private var rebuildClock: Float = 0
    private let rebuildInterval: Float = 1.0 / 30.0

    init(biome: Biome, level: Float) {
        self.level = level

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        biome.waterColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.tint = SIMD3(Float(r), Float(g), Float(b))

        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = UIColor.white          // hue comes from vertex colours
        m.specular.contents = UIColor(white: 1, alpha: 1)
        m.shininess = 0.75
        m.transparency = biome.waterOpacity
        m.blendMode = .alpha
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        m.locksAmbientWithDiffuse = true
        surfaceMaterial = m

        // Far field — flat, just carries the colour out to the horizon.
        let plane = SCNPlane(width: 1400, height: 1400)
        let fm = SCNMaterial()
        fm.lightingModel = .blinn
        fm.diffuse.contents = biome.waterColor
        fm.specular.contents = UIColor(white: 0.9, alpha: 1)
        fm.shininess = 0.7
        fm.transparency = biome.waterOpacity
        fm.blendMode = .alpha
        fm.isDoubleSided = true
        fm.writesToDepthBuffer = false
        plane.materials = [fm]
        farNode.geometry = plane
        farNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        farNode.castsShadow = false
        farNode.renderingOrder = 8

        nearNode.castsShadow = false
        nearNode.renderingOrder = 9

        node.addChildNode(farNode)
        node.addChildNode(nearNode)
    }

    func update(center: SIMD3<Float>, time: Float, dt: Float) {
        farNode.position = SCNVector3(center.x, level - 0.12, center.z)

        rebuildClock += dt
        guard rebuildClock >= rebuildInterval else { return }
        rebuildClock = 0
        rebuildNear(around: SIMD2(center.x, center.z), time: time)
    }

    private func rebuildNear(around c: SIMD2<Float>, time: Float) {
        let cs = cellSize
        // Snap to the cell grid so the facets don't crawl as we move.
        let ox = (c.x / cs).rounded(.down) * cs - span * 0.5
        let oz = (c.y / cs).rounded(.down) * cs - span * 0.5

        let n = cells
        var heights = [Float](repeating: 0, count: (n + 1) * (n + 1))
        for j in 0...n {
            for i in 0...n {
                heights[j * (n + 1) + i] = WaterSystem.wave(ox + Float(i) * cs, oz + Float(j) * cs, time)
            }
        }

        var positions = [SIMD3<Float>]()
        var colors = [SIMD3<Float>]()
        positions.reserveCapacity(n * n * 6)
        colors.reserveCapacity(n * n * 6)

        for j in 0..<n {
            for i in 0..<n {
                let x0 = ox + Float(i) * cs, x1 = x0 + cs
                let z0 = oz + Float(j) * cs, z1 = z0 + cs
                let h00 = heights[j * (n + 1) + i]
                let h10 = heights[j * (n + 1) + i + 1]
                let h01 = heights[(j + 1) * (n + 1) + i]
                let h11 = heights[(j + 1) * (n + 1) + i + 1]

                let a = SIMD3(x0, level + h00, z0)
                let b = SIMD3(x1, level + h10, z0)
                let d = SIMD3(x0, level + h01, z1)
                let e = SIMD3(x1, level + h11, z1)

                append(a, d, b, &positions, &colors)
                append(b, d, e, &positions, &colors)
            }
        }

        let geo = GeometryKit.flatShaded(positions: positions, colors: colors)
        geo.materials = [surfaceMaterial]
        nearNode.geometry = geo
    }

    private func append(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
                        _ positions: inout [SIMD3<Float>], _ colors: inout [SIMD3<Float>]) {
        positions.append(a); positions.append(b); positions.append(c)
        // Crests catch the light, troughs sit deeper.
        let mid = (a.y + b.y + c.y) / 3 - level
        let lift = simd_clamp(0.80 + mid * 0.52, 0.60, 1.34)
        let col = simd_clamp(tint * lift, SIMD3(repeating: 0), SIMD3(repeating: 1))
        colors.append(col); colors.append(col); colors.append(col)
    }

    /// The surface the boat rides on — identical to what's drawn.
    func height(at p: SIMD2<Float>, time: Float) -> Float {
        level + WaterSystem.wave(p.x, p.y, time)
    }

    static func wave(_ x: Float, _ z: Float, _ t: Float) -> Float {
        0.60 * sin(x * 0.085 + t * 0.80)
        + 0.42 * sin(z * 0.125 + t * 0.62)
        + 0.24 * sin((x + z) * 0.048 + t * 1.15)
    }
}
