import SwiftUI

/// Region-specific diffraction. Nothing here translates a texture or sweeps
/// a full-face white gradient. Facets stay fixed; their normals select light.
@MainActor
struct ReviewedFoilLayer: View {
    let profile: ReviewedFoilProfiles.Entry
    let tilt: TiltVector
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            for (index, layer) in profile.layers.enumerated() {
                var region = context
                region.clip(to: ReviewedFoilProfiles.path(layer.include, size: size),
                            style: FillStyle(eoFill: true))
                // Clip separately: combining unrelated exclusion contours
                // with the region using even-odd would create foil islands.
                if !layer.exclude.isEmpty {
                    var outside = Path(CGRect(origin: .zero, size: size))
                    outside.addPath(ReviewedFoilProfiles.path(layer.exclude, size: size))
                    region.clip(to: outside, style: FillStyle(eoFill: true))
                }
                region.opacity = layer.strength
                if layer.material == .radialFans {
                    drawFans(context: &region, size: size)
                } else if layer.material == .goldStars || layer.material == .spectralStars {
                    drawStars(context: &region, size: size, border: layer.material == .goldStars)
                } else {
                    drawFacets(context: &region, size: size, material: layer.material,
                               seed: seed &+ UInt64(index) &* 7919)
                }
            }
        }
    }

    private func drawStars(context: inout GraphicsContext, size: CGSize, border: Bool) {
        var random = PackSeedGenerator(seed: seed &+ 3931)
        func next() -> Double { Double(random.next() >> 11) / Double(1 << 53) }
        for _ in 0..<(border ? 105 : 66) {
            let along = next(), edge = Int(next() * 4)
            let x = border ? (edge < 2 ? along : (edge == 2 ? 0.025 : 0.975)) : next()
            let y = border ? (edge >= 2 ? along : (edge == 0 ? 0.02 : 0.98)) : next()
            let radius = (0.004 + next() * (border ? 0.006 : 0.009)) * size.width
            let phase = next() * .pi * 2
            let response = Self.starResponse(phase: phase, tilt: tilt, goldBorder: border)
            var path = Path()
            for point in 0..<10 {
                let angle = Double(point) / 10 * .pi * 2 + phase
                let r = point.isMultiple(of: 2) ? radius : radius * 0.43
                let p = CGPoint(x: x * size.width + cos(angle) * r,
                                y: y * size.height + sin(angle) * r)
                if point == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            let color = border ? Color(red: 1, green: 0.89, blue: 0.36)
                : Color(hue: Self.wrap(phase / (.pi * 2) + tilt.nx * 0.22), saturation: 0.62, brightness: 1)
            context.fill(path, with: .color(color.opacity(0.12 + response * 0.82)))
        }
    }

    private func drawFacets(context: inout GraphicsContext, size: CGSize,
                            material: ReviewedFoilProfiles.Material, seed: UInt64) {
        let groups = ReviewedFacetCache.groups(seed: seed, material: material)
        context.scaleBy(x: size.width, y: size.height)
        if material != .microEtching {
            context.fill(Path(CGRect(x: 0, y: 0, width: 1, height: 1)),
                with: .color(.black.opacity(material == .goldFragments ? 0.18 : 0.08)))
        }
        for (group, path) in groups.enumerated() {
            let normalGroup = group % ReviewedFacetDistribution.normalGroupCount
            let hueGroup = group / ReviewedFacetDistribution.normalGroupCount
            let phase = Double(normalGroup) / Double(ReviewedFacetDistribution.normalGroupCount) * .pi * 2
            let response = Self.facetResponse(phase: phase, tilt: tilt, material: material)
            let hue = Self.wrap(Double(hueGroup) / Double(ReviewedFacetDistribution.hueGroupCount)
                                + tilt.nx * 0.10 - tilt.ny * 0.07)
            let color: Color
            if material == .microEtching {
                color = response > 0.48 ? Color(white: 0.98) : Color(white: 0.09)
            } else if material == .goldFragments {
                // The warm metal remains gold. Only one eighth of the faces
                // diffract toward the sparse red/green flashes seen in the
                // anniversary border; they never become a full rainbow field.
                if hueGroup == 0 {
                    color = Color(hue: normalGroup.isMultiple(of: 2) ? 0.01 : 0.34,
                                  saturation: 0.72, brightness: 1)
                } else {
                    color = Color(hue: 0.125 + sin(phase + tilt.nx * 0.45) * 0.018,
                                  saturation: 0.76, brightness: 1)
                }
            } else {
                color = normalGroup == 0 ? Color(white: 1)
                    : Color(hue: hue, saturation: 0.76, brightness: 1)
            }
            if material == .microEtching {
                context.stroke(path, with: .color(color.opacity((0.08 + response * 0.43) * 0.75)),
                               lineWidth: 0.00090)
            } else {
                // Keep the gold rim untouched. Interior confetti flashes at
                // its peak but spends less of the tilt cycle covering ink.
                let goldRim = material == .goldFragments
                let darkReturn = goldRim ? 0.36 : 0.18
                let reflection = goldRim ? 0.12 + response * 0.86
                    : 0.04 + pow(response, 1.4) * 0.94
                context.fill(path, with: .color(.black.opacity((1 - response) * darkReturn)))
                context.fill(path, with: .color(color.opacity(reflection)))
            }
        }
    }

    private func drawFans(context: inout GraphicsContext, size: CGSize) {
        for fan in profile.fans {
            let center = CGPoint(x: fan.x * size.width, y: fan.y * size.height)
            // Multiple rings of short, tapered dashes form a broad radial fan;
            // not 260 tiny ten-spoke stars stamped across the card.
            for ring in 1...15 {
                let fraction = Double(ring) / 15
                let radius = fan.radius * size.width * fraction
                let count = max(18, Int(20 + fraction * 88))
                for ray in 0..<count {
                    let jitter = sin(Double(ray * 71 + ring * 17) + fan.phase * 7)
                    let angle = Double(ray) / Double(count) * .pi * 2 + fan.phase + jitter * 0.006
                    let light = Self.fanResponse(angle: angle, phase: fan.phase, tilt: tilt)
                    let hue = Self.wrap(angle / (.pi * 2) + tilt.nx * 0.19 - tilt.ny * 0.11)
                    let start = radius - size.width * (0.005 + fraction * 0.009) * (1 + jitter * 0.18)
                    let halfAngle = (0.009 + fraction * 0.006)
                    var dash = Path()
                    dash.move(to: CGPoint(x: center.x + cos(angle - halfAngle) * start,
                                         y: center.y + sin(angle - halfAngle) * start))
                    dash.addLine(to: CGPoint(x: center.x + cos(angle - halfAngle * 0.7) * radius,
                                            y: center.y + sin(angle - halfAngle * 0.7) * radius))
                    dash.addLine(to: CGPoint(x: center.x + cos(angle + halfAngle * 0.7) * radius,
                                            y: center.y + sin(angle + halfAngle * 0.7) * radius))
                    dash.addLine(to: CGPoint(x: center.x + cos(angle + halfAngle) * start,
                                            y: center.y + sin(angle + halfAngle) * start))
                    dash.closeSubpath()
                    let rimFade = min(1, (1.08 - fraction) * 5)
                    // Tiny low-angle facets provide local contrast on bright
                    // yellow ink; never a broad dark or white card-wide wash.
                    context.fill(dash, with: .color(.black.opacity((1 - light) * 0.10 * rimFade)))
                    // A bright diffractive impression, not purple ink printed
                    // over yellow Pokémon. Screen preserves the source ink.
                    var reflection = context
                    reflection.blendMode = .screen
                    reflection.fill(dash, with: .color(Color(hue: hue, saturation: 0.40, brightness: 1)
                        .opacity(light * 0.94 * rimFade)))
                }
            }
        }
    }

    static func facetResponse(phase: Double, tilt: TiltVector,
                              material: ReviewedFoilProfiles.Material = .confetti) -> Double {
        let coefficients: (x: Double, y: Double, exponent: Double)
        switch material {
        case .microEtching:
            coefficients = (2.05, 1.55, 3.0)
        case .goldFragments:
            coefficients = (2.75, 2.15, 4.5)
        case .silverFragments, .confetti:
            coefficients = (4.65, 3.75, 6.0)
        case .radialFans, .goldStars, .spectralStars:
            coefficients = (3.6, 2.9, 4.0)
        }
        let normal = phase + tilt.nx * coefficients.x + tilt.ny * coefficients.y
        return 0.10 + 0.90 * pow(max(0, cos(normal)), coefficients.exponent)
    }

    static func starResponse(phase: Double, tilt: TiltVector, goldBorder: Bool) -> Double {
        // The embossed gold rim turns more slowly than the loose confetti.
        let speed = goldBorder ? (x: 1.65, y: 1.25) : (x: 3.85, y: 3.10)
        let normal = phase + tilt.nx * speed.x + tilt.ny * speed.y
        return 0.10 + 0.90 * pow(max(0, cos(normal)), goldBorder ? 3.0 : 5.0)
    }

    static func fanResponse(angle: Double, phase: Double, tilt: TiltVector) -> Double {
        let azimuth = atan2(tilt.ny + 0.17, tilt.nx + 0.24)
        let lobe = pow(abs(cos(angle - azimuth)), 5)
        let reveal = 0.45 + 0.55 * pow(abs(sin(phase + tilt.nx * 1.8 + tilt.ny * 1.3)), 2)
        return lobe * reveal
    }

    private static func wrap(_ value: Double) -> Double { value - floor(value) }
}

/// Cache paths, not rendered colors: tilting changes light without rebuilding
/// thousands of polygons. Bounded cache also prevents collection browsing from
/// retaining one full mesh per card forever.
@MainActor
private enum ReviewedFacetCache {
    private static var cache: [String: [Path]] = [:]
    private static var order: [String] = []
    private static let capacity = 24

    static func groups(seed: UInt64, material: ReviewedFoilProfiles.Material) -> [Path] {
        let key = "v2#\(seed)#\(material.rawValue)"
        if let cached = cache[key] { return cached }
        var random = PackSeedGenerator(seed: seed)
        func next() -> Double { Double(random.next() >> 11) / Double(1 << 53) }
        if material != .microEtching {
            let mesh = fragmentMesh(material: material, seed: seed, random: &random)
            remember(mesh, key: key)
            return mesh
        }
        let count = 19000
        var groups = Array(repeating: Path(), count: ReviewedFacetDistribution.groupCount)
        for _ in 0..<count {
            let x = next(), y = next(), angle = next() * .pi * 2
            let group = ReviewedFacetDistribution.group(
                x: x, y: y, independentHue: next(), independentNormal: next(), seed: seed)
            let length = 0.002 + next() * 0.007
            let bend = sin(x * 31 + y * 27) * 0.75 + angle * 0.12
            groups[group].move(to: CGPoint(x: x, y: y))
            groups[group].addQuadCurve(to: CGPoint(x: x + cos(bend) * length,
                y: y + sin(bend) * length * 0.717),
                control: CGPoint(x: x + cos(bend + 0.7) * length * 0.5,
                                 y: y + sin(bend + 0.7) * length * 0.36))
        }
        remember(groups, key: key)
        return groups
    }

    /// Jittered, split cells have finite flake faces and dark seams. Overlapping
    /// random polygons reduced to colored TV noise at the actual 240pt size.
    private static func fragmentMesh(material: ReviewedFoilProfiles.Material,
                                     seed: UInt64,
                                     random: inout PackSeedGenerator) -> [Path] {
        func next() -> Double { Double(random.next() >> 11) / Double(1 << 53) }
        let columns = material == .goldFragments ? 116 : 144
        let rows = Int(Double(columns) / 0.717)
        var points: [CGPoint] = []
        for row in 0...rows {
            for column in 0...columns {
                points.append(CGPoint(x: (Double(column) + (next() - 0.5) * 0.72) / Double(columns),
                                      y: (Double(row) + (next() - 0.5) * 0.72) / Double(rows)))
            }
        }
        var groups = Array(repeating: Path(), count: ReviewedFacetDistribution.groupCount)
        func add(_ vertices: [CGPoint]) {
            let center = CGPoint(x: vertices.map(\.x).reduce(0,+) / Double(vertices.count),
                                 y: vertices.map(\.y).reduce(0,+) / Double(vertices.count))
            let group = ReviewedFacetDistribution.group(
                x: center.x, y: center.y,
                independentHue: next(), independentNormal: next(), seed: seed)
            let inset = 0.72 + next() * 0.22
            for (index, vertex) in vertices.enumerated() {
                let p = CGPoint(x: center.x + (vertex.x-center.x) * inset,
                                y: center.y + (vertex.y-center.y) * inset)
                if index == 0 { groups[group].move(to: p) } else { groups[group].addLine(to: p) }
            }
            groups[group].closeSubpath()
        }
        for row in 0..<rows {
            for column in 0..<columns {
                let a = points[row * (columns+1) + column]
                let b = points[row * (columns+1) + column+1]
                let c = points[(row+1) * (columns+1) + column+1]
                let d = points[(row+1) * (columns+1) + column]
                if next() < 0.42 {
                    add([a,b,c])
                    add([a,c,d])
                } else {
                    add([a,b,c,d])
                }
            }
        }
        return groups
    }

    private static func remember(_ groups: [Path], key: String) {
        if order.count == capacity { cache.removeValue(forKey: order.removeFirst()) }
        cache[key] = groups
        order.append(key)
    }
}

/// Assigns each physical facet its own normal and hue phase. A small smooth
/// component gives neighbouring flakes a weak shared response, while the
/// dominant independent component prevents card-wide directional bands.
enum ReviewedFacetDistribution {
    static let normalGroupCount = 8
    static let hueGroupCount = 8
    static let groupCount = normalGroupCount * hueGroupCount

    static func group(x: Double, y: Double, independentHue: Double,
                      independentNormal: Double, seed: UInt64) -> Int {
        let hue = mixedPhase(independent: independentHue,
                             local: valueNoise(x: x * 12, y: y * 17,
                                               seed: seed &+ 0x9E3779B97F4A7C15),
                             localWeight: 0.18)
        let normal = mixedPhase(independent: independentNormal,
                                local: valueNoise(x: x * 19, y: y * 13,
                                                  seed: seed &+ 0xD1B54A32D192ED03),
                                localWeight: 0.12)
        let hueGroup = min(hueGroupCount - 1, Int(hue * Double(hueGroupCount)))
        let normalGroup = min(normalGroupCount - 1, Int(normal * Double(normalGroupCount)))
        return hueGroup * normalGroupCount + normalGroup
    }

    static func huePhase(x: Double, y: Double, independent: Double, seed: UInt64) -> Double {
        mixedPhase(independent: independent,
                   local: valueNoise(x: x * 12, y: y * 17,
                                     seed: seed &+ 0x9E3779B97F4A7C15),
                   localWeight: 0.18)
    }

    private static func mixedPhase(independent: Double, local: Double,
                                   localWeight: Double) -> Double {
        let independentAngle = independent * .pi * 2
        let localAngle = local * .pi * 2
        let x = cos(independentAngle) * (1 - localWeight) + cos(localAngle) * localWeight
        let y = sin(independentAngle) * (1 - localWeight) + sin(localAngle) * localWeight
        let angle = atan2(y, x) / (.pi * 2)
        return angle < 0 ? angle + 1 : angle
    }

    private static func valueNoise(x: Double, y: Double, seed: UInt64) -> Double {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let tx = smooth(x - Double(x0)), ty = smooth(y - Double(y0))
        let a = lerp(hashUnit(x0, y0, seed), hashUnit(x0 + 1, y0, seed), tx)
        let b = lerp(hashUnit(x0, y0 + 1, seed), hashUnit(x0 + 1, y0 + 1, seed), tx)
        return lerp(a, b, ty)
    }

    private static func hashUnit(_ x: Int, _ y: Int, _ seed: UInt64) -> Double {
        var value = seed ^ UInt64(truncatingIfNeeded: x) &* 0x9E3779B97F4A7C15
        value ^= UInt64(truncatingIfNeeded: y) &* 0xD1B54A32D192ED03
        value ^= value >> 30
        value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value &*= 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value >> 11) / Double(1 << 53)
    }

    private static func smooth(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func lerp(_ a: Double, _ b: Double, _ amount: Double) -> Double {
        a + (b - a) * amount
    }
}
