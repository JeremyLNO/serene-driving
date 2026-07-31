import UIKit

/// Builds the equirectangular sky used both as the scene background
/// and as the image-based lighting environment.
enum SkyFactory {

    /// Azimuth (0...1) where the sun sits in the panorama.
    static let sunAzimuth: CGFloat = 0.25

    static func sky(for biome: Biome, weather: Weather = .clear) -> UIImage {
        let size = CGSize(width: 1024, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let f = UIGraphicsImageRendererFormat.default()
            f.scale = 1
            f.opaque = true
            return f
        }())

        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Vertical gradient: zenith -> horizon -> below.
            let colors = [biome.skyZenith.cgColor, biome.skyHorizon.cgColor, biome.skyLow.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: [0.0, 0.52, 1.0])!
            cg.drawLinearGradient(gradient,
                                  start: .zero,
                                  end: CGPoint(x: 0, y: size.height),
                                  options: [])

            if biome.stars { drawStars(cg, size: size, dense: biome.kind == .space) }
            if biome.kind == .space { drawNebula(cg, size: size) }
            if weather == .aurora { drawAurora(cg, size: size) }

            drawSun(cg, size: size, biome: biome)

            switch biome.kind {
            case .moon:
                drawPlanet(cg, center: CGPoint(x: size.width * 0.72, y: size.height * 0.20),
                           radius: 52, base: rgb(0x4C86C6), accent: rgb(0x6FAE72), glow: rgb(0x9FD3F5))
            case .space:
                drawPlanet(cg, center: CGPoint(x: size.width * 0.63, y: size.height * 0.30),
                           radius: 40, base: rgb(0xC98A5E), accent: rgb(0xE8C79A), glow: rgb(0xF0C89A))
                drawPlanet(cg, center: CGPoint(x: size.width * 0.10, y: size.height * 0.62),
                           radius: 26, base: rgb(0x6C5EA8), accent: rgb(0x9C8AD8), glow: rgb(0xB6A6F0))
            default:
                drawClouds(cg, size: size, biome: biome, heavy: weather == .rain)
            }
        }
    }

    // MARK: - Pieces

    private static func drawSun(_ cg: CGContext, size: CGSize, biome: Biome) {
        let x = size.width * sunAzimuth
        let y = size.height * (0.5 - 0.46 * CGFloat(biome.sunElevation))
        let glowRadius: CGFloat = biome.stars ? 70 : 190

        var comps = biome.sunColor.cgColor.components ?? [1, 1, 1, 1]
        if comps.count < 4 { comps = [comps[0], comps[0], comps[0], 1] }
        let inner = UIColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 0.95).cgColor
        let outer = UIColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 0.0).cgColor

        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [inner, outer] as CFArray, locations: [0, 1]) {
            cg.saveGState()
            cg.setBlendMode(.plusLighter)
            cg.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                  endCenter: CGPoint(x: x, y: y), endRadius: glowRadius, options: [])
            cg.restoreGState()
        }

        cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        let r: CGFloat = biome.stars ? 9 : 15
        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func drawStars(_ cg: CGContext, size: CGSize, dense: Bool) {
        var rng = SeededRandom(dense ? 991 : 447)
        let count = dense ? 900 : 520
        for _ in 0..<count {
            let x = CGFloat(rng.next()) * size.width
            let y = CGFloat(rng.next()) * size.height * (dense ? 1.0 : 0.88)
            let r = CGFloat(rng.range(0.4, 1.7))
            let a = CGFloat(rng.range(0.25, 1.0))
            let tint = rng.next()
            let color = UIColor(red: 1, green: 0.94 + 0.06 * CGFloat(tint), blue: 0.9 + 0.1 * CGFloat(tint), alpha: a)
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
        }
    }

    private static func drawNebula(_ cg: CGContext, size: CGSize) {
        var rng = SeededRandom(7717)
        let tints = [rgb(0x6E4FA8), rgb(0x2F5FA8), rgb(0xA85C8E), rgb(0x3E8FA0)]
        cg.saveGState()
        cg.setBlendMode(.plusLighter)
        for i in 0..<26 {
            let c = tints[i % tints.count].withAlphaComponent(CGFloat(rng.range(0.05, 0.14)))
            let x = CGFloat(rng.next()) * size.width
            let y = CGFloat(rng.next()) * size.height
            let r = CGFloat(rng.range(60, 220))
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [c.cgColor, c.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1]) {
                cg.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                      endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
            }
        }
        cg.restoreGState()
    }

    private static func drawClouds(_ cg: CGContext, size: CGSize, biome: Biome, heavy: Bool = false) {
        var rng = SeededRandom(UInt64(biome.kind.rawValue) &* 31 &+ 13)
        cg.saveGState()
        for _ in 0..<(heavy ? 52 : 34) {
            let x = CGFloat(rng.next()) * size.width
            let y = CGFloat(rng.range(0.04, heavy ? 0.5 : 0.44)) * size.height
            let w = CGFloat(rng.range(heavy ? 120 : 70, heavy ? 340 : 240))
            let h = w * CGFloat(rng.range(0.14, 0.30))
            let a = CGFloat(rng.range(heavy ? 0.18 : 0.10, heavy ? 0.5 : 0.35))
            let c = (heavy ? rgb(0x6E7886) : UIColor.white).withAlphaComponent(a)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [c.cgColor, c.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1]) {
                cg.saveGState()
                cg.translateBy(x: x, y: y)
                cg.scaleBy(x: 1, y: h / w)
                cg.drawRadialGradient(g, startCenter: .zero, startRadius: 0,
                                      endCenter: .zero, endRadius: w, options: [])
                cg.restoreGState()
            }
        }
        cg.restoreGState()
    }

    private static func drawPlanet(_ cg: CGContext, center: CGPoint, radius: CGFloat,
                                   base: UIColor, accent: UIColor, glow: UIColor) {
        cg.saveGState()
        // halo
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [glow.withAlphaComponent(0.35).cgColor,
                                       glow.withAlphaComponent(0).cgColor] as CFArray,
                              locations: [0, 1]) {
            cg.setBlendMode(.plusLighter)
            cg.drawRadialGradient(g, startCenter: center, startRadius: radius * 0.85,
                                  endCenter: center, endRadius: radius * 2.1, options: [])
            cg.setBlendMode(.normal)
        }

        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        cg.setFillColor(base.cgColor)
        cg.fillEllipse(in: rect)

        // continents / bands
        cg.saveGState()
        cg.addEllipse(in: rect)
        cg.clip()
        var rng = SeededRandom(UInt64(radius * 977))
        cg.setFillColor(accent.withAlphaComponent(0.85).cgColor)
        for _ in 0..<7 {
            let bx = center.x + CGFloat(rng.range(-1, 1)) * radius
            let by = center.y + CGFloat(rng.range(-1, 1)) * radius
            let bw = radius * CGFloat(rng.range(0.3, 0.9))
            let bh = radius * CGFloat(rng.range(0.15, 0.5))
            cg.fillEllipse(in: CGRect(x: bx - bw / 2, y: by - bh / 2, width: bw, height: bh))
        }
        // terminator shadow
        if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [UIColor.black.withAlphaComponent(0).cgColor,
                                        UIColor.black.withAlphaComponent(0.75).cgColor] as CFArray,
                               locations: [0.25, 1]) {
            cg.drawLinearGradient(sg,
                                  start: CGPoint(x: center.x - radius, y: center.y - radius),
                                  end: CGPoint(x: center.x + radius, y: center.y + radius),
                                  options: [])
        }
        cg.restoreGState()
        cg.restoreGState()
    }

    /// Slow curtains of light for aurora nights.
    private static func drawAurora(_ cg: CGContext, size: CGSize) {
        var rng = SeededRandom(4_221)
        let tints = [rgb(0x4FE3A8), rgb(0x3FBFD8), rgb(0x8E6FE0)]
        cg.saveGState()
        cg.setBlendMode(.plusLighter)
        for band in 0..<7 {
            let tint = tints[band % tints.count]
            let baseY = size.height * CGFloat(rng.range(0.10, 0.42))
            let height = size.height * CGFloat(rng.range(0.10, 0.26))
            let x0 = CGFloat(rng.next()) * size.width - size.width * 0.2
            let width = size.width * CGFloat(rng.range(0.28, 0.62))

            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [tint.withAlphaComponent(0).cgColor,
                                              tint.withAlphaComponent(CGFloat(rng.range(0.20, 0.40))).cgColor,
                                              tint.withAlphaComponent(0).cgColor] as CFArray,
                                     locations: [0, 0.45, 1]) else { continue }

            // Ripple the band into a soft curtain rather than a straight bar.
            var x = x0
            while x < x0 + width {
                let wobble = sin(x / size.width * .pi * CGFloat(rng.range(3, 7))) * height * 0.22
                let sliceW = size.width * 0.012
                cg.saveGState()
                cg.clip(to: CGRect(x: x, y: baseY + wobble, width: sliceW, height: height))
                cg.drawLinearGradient(g,
                                      start: CGPoint(x: x, y: baseY + wobble),
                                      end: CGPoint(x: x, y: baseY + wobble + height),
                                      options: [])
                cg.restoreGState()
                x += sliceW
            }
        }
        cg.restoreGState()
    }

    // MARK: - Particle sprite

    static let softDot: UIImage = {
        let size = CGSize(width: 64, height: 64)
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = 1
        f.opaque = false
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            let cg = ctx.cgContext
            let c = CGPoint(x: 32, y: 32)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.white.cgColor,
                                           UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1]) {
                cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: 32, options: [])
            }
        }
    }()

    static let flake: UIImage = {
        let size = CGSize(width: 64, height: 64)
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = 1
        f.opaque = false
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            cg.fillEllipse(in: CGRect(x: 20, y: 20, width: 24, height: 24))
            cg.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.fillEllipse(in: CGRect(x: 12, y: 12, width: 40, height: 40))
        }
    }()
}
