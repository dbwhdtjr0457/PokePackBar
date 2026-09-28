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
            let response = Self.facetResponse(phase: phase, tilt: tilt)
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
            let phase = Double(group % 8) / 8 * .pi * 2
            let response = Self.facetResponse(phase: phase, tilt: tilt)
            let hue = Self.wrap(Double(group / 8) / 6 + tilt.nx * 0.26 - tilt.ny * 0.19)
            let color: Color
            if material == .microEtching {
                color = response > 0.48 ? Color(white: 0.98) : Color(white: 0.09)
            } else if material == .goldFragments {
                // Warm substrate, with isolated red/green diffraction observed
                // in the anniversary foil. This is NOT the MUR gold material.
                color = group % 3 == 0
                    ? Color(hue: hue, saturation: 0.82, brightness: 1)
                    : Color(hue: 0.13 + sin(phase + tilt.nx * 0.8) * 0.065,
                            saturation: group % 4 == 0 ? 0.34 : 0.85, brightness: 1)
            } else {
                color = group % 7 == 0 ? Color(white: 1)
                    : Color(hue: hue, saturation: 0.76, brightness: 1)
            }
            if material == .microEtching {
                context.stroke(path, with: .color(color.opacity(0.06 + response * 0.27)),
                               lineWidth: 0.00085)
            } else {
                context.fill(path, with: .color(.black.opacity((1 - response) * 0.36)))
                context.fill(path, with: .color(color.opacity(0.12 + response * 0.86)))
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

    static func facetResponse(phase: Double, tilt: TiltVector) -> Double {
        let normal = phase + tilt.nx * 3.6 + tilt.ny * 2.9
        return 0.12 + 0.88 * pow(max(0, cos(normal)), 4)
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
        let key = "\(seed)#\(material.rawValue)"
        if let cached = cache[key] { return cached }
        var random = PackSeedGenerator(seed: seed)
        func next() -> Double { Double(random.next() >> 11) / Double(1 << 53) }
        if material != .microEtching {
            let mesh = fragmentMesh(material: material, random: &random)
            remember(mesh, key: key)
            return mesh
        }
        let count = 19000
        var groups = Array(repeating: Path(), count: 48)
        for index in 0..<count {
            let x = next(), y = next(), angle = next() * .pi * 2
            // Spatial color coherence without a drawn rainbow stripe: each
            // region still contains eight independently oriented facet groups.
            let band = min(5, Int((x * 0.42 + y * 0.58) * 6))
            let group = band * 8 + index % 8
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
        var groups = Array(repeating: Path(), count: 48)
        func add(_ vertices: [CGPoint], band: Int) {
            let group = band * 8 + min(7, Int(next() * 8))
            let center = CGPoint(x: vertices.map(\.x).reduce(0,+) / Double(vertices.count),
                                 y: vertices.map(\.y).reduce(0,+) / Double(vertices.count))
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
                let band = max(0, min(5, Int((a.x * 0.42 + a.y * 0.58) * 6)))
                if next() < 0.42 {
                    add([a,b,c], band: band)
                    add([a,c,d], band: band)
                } else {
                    add([a,b,c,d], band: band)
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
