import AppKit
import SwiftUI

/// Engraved foil needs both bright and dark facets: an additive white layer
/// cannot show a highlight on an already-white scan. Geometry is card-locked;
/// only its response to the fixed light changes with the viewing angle.
enum FoilReliefMaterial: Equatable {
    case illustration
    case gold(FoilPattern)
    case engraved(FoilPattern, FoilTexture)
    case linear(FoilPattern)
    case white
    case black
    case chrome
    case printedRGB
    case classicEtched
    case microEtched(FoilMicroRelief)
    case neoShining

    static let neoShiningCardIDs = Set((106...113).map { "neo4-\($0)" })

    init?(pattern: FoilPattern, texture: FoilTexture = .none, cardID: String? = nil) {
        // Even linear microfacets create visible diagonal grooves here.
        // Generations RC is handled by the unetched sheet renderer instead.
        if pattern == .satin, cardID?.hasPrefix("g1-RC") == true { return nil }
        if pattern == .refractor, let cardID, Self.neoShiningCardIDs.contains(cardID) {
            self = .neoShining
            return
        }
        if let microRelief = FoilMicroRelief(pattern: pattern) {
            self = .microEtched(microRelief)
            return
        }
        switch pattern {
        case .specialIllustration: self = .illustration
        case .rainbowSplash: self = .engraved(.rainbowSplash, .swordShieldEtched)
        case .stone: self = .engraved(.stone, .embossed)
        case .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .megaGold:
            self = .gold(pattern)
        case .whiteEtched: self = .white
        case .blackEtched, .monochrome: self = .black
        case .line, .vmaxRays:
            self = .engraved(pattern, texture)
        case .starfield where texture != .none:
            self = .engraved(pattern, texture)
        case .satin, .sheen, .verticalLine, .waterWeb, .tinsel, .rainbow, .mirage:
            if texture != .none && texture != .paper {
                self = .engraved(pattern, texture)
            } else if pattern != .rainbow {
                self = .linear(pattern)
            } else {
                return nil
            }
        default: return nil
        }
    }

    var cacheKey: String {
        switch self {
        case .illustration: "illustration"
        case .gold(let pattern): pattern.rawValue
        case .engraved(let pattern, let texture): "\(pattern.rawValue)-\(texture.rawValue)"
        case .linear(let pattern): "sheet-\(pattern.rawValue)"
        case .white: "white"
        case .black: "black"
        case .chrome: "chrome30"
        case .printedRGB: "printed-rgb30"
        case .classicEtched: "classic30"
        case .microEtched(let finish): "micro-\(finish.rawValue)"
        case .neoShining: "neo-shining-grain"
        }
    }

    var columns: Int {
        switch self {
        case .illustration: 260
        case .gold(.megaGold): 400
        case .gold: 250
        case .engraved: 280
        case .linear: 280
        case .white, .black: 144
        case .chrome: 270
        case .printedRGB: 240
        case .classicEtched: 220
        case .microEtched(let finish): finish.columns
        case .neoShining: 240
        }
    }

    /// These are reflection colors, not colors applied across the card face.
    var reflectionColors: [Color] {
        switch self {
        case .neoShining:
            [Color(white: 0.98), Color(white: 0.72), Color(white: 0.88)]
        case .microEtched(let finish): finish.reflectionColors
        case .gold:
            [Color(red: 1.0, green: 0.95, blue: 0.64),
             Color(red: 1.0, green: 0.81, blue: 0.23),
             Color(red: 1.0, green: 0.98, blue: 0.81)]
        case .white:
            [Color(white: 1), Color(white: 0.87), Color(white: 0.96)]
        case .black:
            [Color(white: 0.95), Color(white: 0.72), Color(white: 1)]
        case .chrome:
            [Color(white: 1), Color(red: 0.78, green: 0.90, blue: 0.96), Color(white: 0.90)]
        case .printedRGB:
            [Color(white: 1), Color(white: 0.93), Color(white: 0.82)]
        case .classicEtched:
            [Color(red: 1, green: 0.93, blue: 0.68), Color(white: 0.98), Color(red: 0.89, green: 0.89, blue: 0.77)]
        case .engraved(.stone, _):
            [Color(white: 0.98), Color(red: 0.86, green: 0.79, blue: 0.62), Color(white: 0.72)]
        case .engraved(.rainbowSplash, _):
            [Color(red: 0.18, green: 0.92, blue: 1),
             Color(red: 1, green: 0.36, blue: 0.67),
             Color(red: 0.78, green: 0.48, blue: 1),
             Color(red: 1, green: 0.89, blue: 0.30)]
        case .engraved(.starfield, _):
            [Color(white: 0.98), Color(white: 0.75),
             Color(red: 0.80, green: 0.91, blue: 0.96)]
        case .engraved:
            [Color(red: 0.62, green: 0.93, blue: 1.0),
             Color(red: 1.0, green: 0.88, blue: 0.64),
             Color(red: 0.86, green: 0.73, blue: 1.0),
             Color(red: 0.96, green: 0.98, blue: 1.0)]
        case .linear:
            [Color(red: 0.89, green: 0.97, blue: 1.0),
             Color(red: 0.72, green: 0.86, blue: 0.96),
             Color(red: 1.0, green: 0.97, blue: 0.88)]
        case .illustration:
            [Color(red: 0.70, green: 0.94, blue: 1.0),
             Color(red: 0.86, green: 0.77, blue: 1.0),
             Color(red: 1.0, green: 0.79, blue: 0.90),
             Color(red: 1.0, green: 0.94, blue: 0.72),
             Color(red: 0.78, green: 1.0, blue: 0.88),
             Color(red: 0.94, green: 0.98, blue: 1.0)]
        }
    }

    var shadowColor: Color {
        switch self {
        case .gold: Color(red: 0.29, green: 0.14, blue: 0.015)
        case .white: Color(white: 0.22)
        case .black: Color(white: 0.025)
        case .chrome, .printedRGB, .classicEtched: Color(white: 0.12)
        case .microEtched: Color(white: 0.36)
        case .neoShining: Color(white: 0.08)
        case .illustration, .engraved, .linear: Color(red: 0.13, green: 0.15, blue: 0.25)
        }
    }

    /// Diffraction changes the ridge's reflected hue continuously with angle;
    /// it does not paint moving bands on the card. Gold/Neo retain their palettes.
    @MainActor
    func reflectionColors(angle: Double) -> [Color] {
        let travel: Double
        switch self {
        case .illustration: travel = 0.15
        case .engraved(.starfield, _), .engraved(.stone, _): travel = 0
        case .engraved: travel = 0.10
        case .microEtched: travel = 0.07
        case .linear: travel = 0.12
        default: travel = 0
        }
        guard travel != 0 else { return reflectionColors }
        return reflectionColors.map { color in
            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return color }
            let hue = Double(rgb.hueComponent) + angle * travel
            return Color(hue: hue - floor(hue), saturation: max(isIllustrationEtch ? 0.52 : 0.32, Double(rgb.saturationComponent)),
                         brightness: Double(rgb.brightnessComponent))
        }
    }

    /// Ridge coverage, not a second full-face white overlay. Include SIR here:
    /// it was previously excluded from both angular gain and diffraction.
    func highlightGain(magnitude: Double) -> Double {
        if isIllustrationEtch { return 1.10 + magnitude * 0.96 }
        if isGold { return 1.22 + magnitude * 1.00 }
        if isEngraved || isMicroEtched { return 1.08 + magnitude * 1.18 }
        return 1
    }

    /// Dense ridges and isolated glints have different jobs. Attenuate only
    /// the continuous micro-coating; preserve its normals, colors and peaks.
    /// Dark photographic MUR scans need more protection than flat gold art.
    func coatingGain(meanLuminance: Double?) -> Double {
        switch self {
        case .gold(.megaGold):
            return (meanLuminance ?? 1) < 0.50 ? 0.30 : 0.44
        case .illustration: return 0.70
        case .engraved(.rainbowSplash, _): return 0.55
        case .engraved(.stone, _): return 0.65
        case .engraved(.satin, _), .engraved(.mirage, _): return 0.72
        default: return 1
        }
    }

    /// Amazing Rare scans already contain the colored splash. Keep flat ink
    /// much quieter than its detailed splash/subject; this is image-guided
    /// roughness, not a claim to have the factory's selective coating mask.
    func imageResponse(light: Double, edge: Double) -> Double {
        guard case .engraved(.rainbowSplash, _) = self else { return 1 }
        if light < 0.20 && edge > 0.40 { return 0.12 }
        return 0.12 + 0.88 * sqrt(max(0, min(1, edge)))
    }

    var shadowStrength: Double {
        switch self {
        case .white: 0.58
        case .linear: 0.18
        case .chrome: 0.36
        case .printedRGB: 0.26
        case .microEtched(let finish): finish.shadowStrength
        case .illustration: 0.25
        case .engraved: 0.18
        default: 0.38
        }
    }

    var facetLength: Double {
        switch self {
        case .illustration: 0.54
        case .gold(.megaGold): 0.40
        case .gold: 0.52
        case .neoShining: 0.12
        case .engraved(.starfield, _), .engraved(.cosmos, _): 0.40
        case .engraved: 0.62
        case .linear: 0.42
        case .chrome: 0.24
        case .printedRGB: 0.34
        case .classicEtched: 0.20
        case .microEtched(let finish): finish.facetLength
        default: 0.52
        }
    }

    var reflectionExponent: Double {
        switch self {
        case .linear: 5.0
        default: 2.0
        }
    }

    var followsArtwork: Bool {
        if case .linear = self { return false }
        if self == .neoShining { return false }
        return true
    }

    var isMicroEtched: Bool {
        if case .microEtched = self { return true }
        return false
    }

    /// SAR relief is a correlated etched sheet, not independently oriented
    /// glitter. Keep its sampling and ink response separate from metal grain.
    var isIllustrationEtch: Bool { self == .illustration }

    var isEngraved: Bool {
        if case .engraved = self { return true }
        return false
    }

    var isLinear: Bool {
        if case .linear = self { return true }
        return false
    }

    var isGold: Bool {
        if case .gold = self { return true }
        return false
    }

    /// Sun & Moon and Sword & Shield gold secret rares draw the illustration
    /// in golden lines that "sparkle with a rainbow prism" when hit by light
    /// (Bleeding Cool, Gold Secret Rares). Other gold families stay warm metal.
    var hasPrismLinework: Bool {
        if case .gold(let pattern) = self {
            return pattern == .sunMoonGold || pattern == .swordShieldGold
        }
        return false
    }

    /// Correlation scale is material-specific; gold keeps a finer metallic grain
    /// while illustration etching reveals small connected patches of relief.
    var lightNeighbourhoodColumns: Double? {
        if isIllustrationEtch { return 24 }
        if isGold { return 38 }
        if isMicroEtched { return 32 }
        if isEngraved { return 28 }
        return nil
    }

    func reliefShadowGain(magnitude: Double) -> Double {
        if isIllustrationEtch { return 0.70 + magnitude * 0.80 }
        if isMicroEtched || isEngraved { return 0.50 + magnitude * 0.65 }
        if isGold { return 0.90 + magnitude * 0.45 }
        return 1
    }

    var ridgeWidth: Double {
        if isIllustrationEtch { return 0.60 }
        if isEngraved { return 0.66 }
        if self == .neoShining { return 0.55 }
        if self == .gold(.megaGold) { return 0.88 }
        if isGold { return 0.70 }
        return isMicroEtched ? 0.60 : 0.44
    }

    var lengthVariation: Double {
        if isGold || self == .neoShining { return 0.14 }
        if isIllustrationEtch { return 0.20 }
        if isEngraved || isLinear { return 0.22 }
        return isMicroEtched ? 0.34 : 0.66
    }

    static func blendRidgeDirection(_ a: Double, _ b: Double, weight: Double) -> Double {
        // A ridge is an unoriented axis: +pi and -pi/0 must not average into
        // a perpendicular scratch. Blend doubled angles, then halve.
        0.5 * atan2(sin(a * 2) * (1 - weight) + sin(b * 2) * weight,
                    cos(a * 2) * (1 - weight) + cos(b * 2) * weight)
    }

    static func dispersedNormal(row: Int, column: Int, phase: Double, underlying: Double) -> Double {
        sin(Double(row) * 2.399 + Double(column) * 1.3247 + phase) * 1.9 + underlying * 0.22
    }
}

@MainActor
struct FoilReliefLayer: View {
    let material: FoilReliefMaterial
    let seed: UInt64
    let tilt: TiltVector
    var imageField: FoilImageField? = nil
    var coatingScale: Double = 1

    private static let lightLevels = 8
    private static let prismHues = 6
    private static let shadowLevels = 4

    var body: some View {
        if case .linear(let pattern) = material {
            FoilDirectionalSheet(pattern: pattern, tilt: tilt)
        } else {
            etchedBody
        }
    }

    private var etchedBody: some View {
        let facets = FoilReliefCache.facets(material: material, seed: seed, imageField: imageField)
        return Canvas { context, size in
            let angle = tilt.nx * 2.65 + tilt.ny * 1.9
            let colors = material.reflectionColors(angle: angle)
            var reflections = Array(repeating: Path(),
                                    count: colors.count * Self.lightLevels)
            var shadows = Array(repeating: Path(), count: Self.shadowLevels)
            var peaks = Path()
            var prisms = Array(repeating: Path(), count: Self.prismHues)
            let pitch = size.width / CGFloat(material.columns)
            let angleCos = cos(angle)
            let angleSin = sin(angle)
            // A face-on etched sheet is not a layer of dark dust. Let tilt
            // reveal the relief, chiefly through the illuminated ridge edges.
            let pairedRelief = material.lightNeighbourhoodColumns != nil
            let highlightGain = material.highlightGain(magnitude: tilt.magnitude)
            let shadowGain = material.reliefShadowGain(magnitude: tilt.magnitude)
            let coatingGain = material.coatingGain(meanLuminance: imageField?.meanLuminance) * coatingScale

            for facet in facets {
                let illumination = FoilAreaLighting.facetIllumination(
                    x: facet.x, y: facet.y, phase: facet.lightPhase, angle: angle,
                    minimum: pairedRelief ? 0.28 : 0.18)
                let alignment = facet.normalCos * angleCos - facet.normalSin * angleSin
                let reflected = pow(max(0, alignment), material.reflectionExponent)
                    * (0.025 + illumination * 0.975) * facet.responseWeight
                let occluded = pow(max(0, -alignment), 1.8)
                    * (0.06 + illumination * 0.94) * facet.responseWeight
                // A lit ridge needs a neighbouring dark edge to read as relief
                // on a bright scan. Both remain microscopic, never a face wash.
                let shadow = max(occluded, pairedRelief ? reflected * 0.65 : 0)
                let center = CGPoint(x: facet.x * size.width,
                                     y: facet.y * size.height)
                let vx = pitch * facet.halfVectorX
                let vy = pitch * facet.halfVectorY
                let start = CGPoint(x: center.x - vx, y: center.y - vy)
                let end = CGPoint(x: center.x + vx, y: center.y + vy)

                if reflected > 0.05 {
                    let level = min(Self.lightLevels - 1,
                                    Int(reflected * Double(Self.lightLevels)))
                    let colorPhase = facet.colorPhase
                    let colorIndex = Int(abs(colorPhase * 17)) % colors.count
                    let index = colorIndex * Self.lightLevels + level
                    reflections[index].move(to: start)
                    reflections[index].addLine(to: end)
                    if facet.prism && reflected > 0.22 {
                        // Hue follows position along the line and the viewing
                        // angle, so the prism colours travel as the card tilts.
                        let hue = facet.colorPhase * 2.3 + facet.x * 1.7 + facet.y * 0.9 + angle * 0.42
                        let bucket = Int((hue - floor(hue)) * Double(Self.prismHues)) % Self.prismHues
                        prisms[bucket].move(to: start)
                        prisms[bucket].addLine(to: end)
                    }
                    if reflected > 0.72 && facet.glint {
                        peaks.addEllipse(in: CGRect(x: center.x - pitch * 0.25,
                                                    y: center.y - pitch * 0.20,
                                                    width: pitch * 0.5,
                                                    height: pitch * 0.4))
                    }
                }
                if shadow > 0.10 {
                    let level = min(Self.shadowLevels - 1,
                                    Int(shadow * Double(Self.shadowLevels)))
                    let offset = pairedRelief ? pitch * 0.32 : 0
                    let shadowOffset = CGVector(dx: facet.bevelX * offset, dy: facet.bevelY * offset)
                    shadows[level].move(to: CGPoint(x: start.x + shadowOffset.dx, y: start.y + shadowOffset.dy))
                    shadows[level].addLine(to: CGPoint(x: end.x + shadowOffset.dx, y: end.y + shadowOffset.dy))
                }
            }

            for level in 0..<Self.shadowLevels {
                let energy = Double(level + 1) / Double(Self.shadowLevels)
                context.stroke(shadows[level],
                               with: .color(material.shadowColor.opacity(energy * material.shadowStrength * shadowGain * coatingGain)),
                               style: StrokeStyle(lineWidth: pitch * (material.isIllustrationEtch ? 0.44 : (material.isMicroEtched ? 0.66 : 0.46)),
                                                  lineCap: .round))
            }
            for colorIndex in colors.indices {
                for level in 0..<Self.lightLevels {
                    let energy = Double(level + 1) / Double(Self.lightLevels)
                    let index = colorIndex * Self.lightLevels + level
                    context.stroke(reflections[index],
                                   with: .color(colors[colorIndex].opacity(min(1, (0.12 + energy * 0.78) * highlightGain) * coatingGain)),
                                   style: StrokeStyle(lineWidth: pitch * material.ridgeWidth,
                                                      lineCap: .round))
                }
            }
            context.fill(peaks, with: .color(colors[0].opacity(min(1, 0.92 * highlightGain))))
            if material.hasPrismLinework {
                for bucket in 0..<Self.prismHues {
                    context.stroke(prisms[bucket],
                                   with: .color(Color(hue: Double(bucket) / Double(Self.prismHues),
                                                      saturation: 0.78, brightness: 1)
                                       .opacity(min(1, 0.85 * highlightGain) * coatingGain)),
                                   style: StrokeStyle(lineWidth: pitch * material.ridgeWidth * 1.25,
                                                      lineCap: .round))
                }
            }
        }
    }
}

/// Fixed microscopic geometry is cached across hover frames. The bounded
/// cache avoids generating tens of thousands of ridges on every pointer event.
@MainActor
private enum FoilReliefCache {
    struct Facet {
        let x: Double
        let y: Double
        let normalCos: Double
        let normalSin: Double
        let halfVectorX: Double
        let halfVectorY: Double
        let bevelX: Double
        let bevelY: Double
        let colorPhase: Double
        let lightPhase: Double
        let glint: Bool
        let responseWeight: Double
        /// On a golden illustration line of a prism-linework gold card.
        let prism: Bool
    }

    private final class Surface {
        let facets: [Facet]
        init(_ facets: [Facet]) { self.facets = facets }
    }

    private static let cache: NSCache<NSString, Surface> = {
        let cache = NSCache<NSString, Surface>()
        cache.countLimit = 16
        return cache
    }()

    static func facets(material: FoilReliefMaterial, seed: UInt64, imageField: FoilImageField?) -> [Facet] {
        let key = "\(material.cacheKey)#\(seed)#\(imageField?.key ?? "procedural")" as NSString
        if let cached = cache.object(forKey: key) { return cached.facets }
        let columns = material.columns
        let rows = Int(Double(columns) / 0.717)
        var state = seed | 1
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64.max >> 11)
        }
        let phase = random() * Double.pi * 2
        var facets: [Facet] = []
        facets.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let jitter = material.isIllustrationEtch || material.isEngraved ? 0.88 : 0.64
                let x = (Double(column) + 0.5 + (random() - 0.5) * jitter) / Double(columns)
                let y = (Double(row) + 0.5 + (random() - 0.5) * jitter) / Double(rows)
                let grain = random()
                var geometry = geometry(material: material, x: x, y: y, phase: phase)
                if material.isIllustrationEtch {
                    // The printed scan is not the factory emboss plate. Use
                    // subpixel, locally correlated ridges without inventing
                    // fingerprint centres or continuous screen-wide lines.
                    geometry.direction = sin(x * 9 + y * 7 + phase) * 1.2
                        + cos(y * 13 - x * 5 + phase) * 0.8
                    geometry.normal = sin(Double(row) * 2.399 + x * 73 + phase) * 1.7
                        + sin(x * 12 + y * 9 + phase) * 0.7
                }
                if material.isEngraved || material.isMicroEtched {
                    // Regular samples of sinusoidal ridges alias into broad
                    // screen-space wires. Keep each family's ridge direction,
                    // but distribute facet normals below one display pixel.
                    geometry.normal = FoilReliefMaterial.dispersedNormal(
                        row: row, column: column, phase: phase, underlying: geometry.normal)
                }
                var responseWeight = 1.0
                var prism = false
                if material.followsArtwork, let imageField {
                    let sample = imageField.sample(x: x, y: y)
                    if material.isMicroEtched {
                        // Printed gradients are only a weak steering field,
                        // not an emboss scan. Preserve the six sheet families
                        // instead of replacing them with one image-edge formula.
                        let weight = sample.edge * 0.28
                        geometry.direction = FoilReliefMaterial.blendRidgeDirection(
                            geometry.direction, sample.direction, weight: weight)
                        // Keep high-contrast dark ink edges legible and clean.
                        // This is deliberately conservative: flat dark artwork
                        // remains reflective instead of being mistaken for ink.
                        if sample.light < 0.20 && sample.edge > 0.40 {
                            responseWeight = 0.18
                        }
                    } else if material.isIllustrationEtch || material.isGold || material.isEngraved {
                        // Printed luminance is not an emboss plate. It may
                        // gently orient an etched ridge but cannot replace its
                        // normal or assign rainbow color to every ink edge.
                        geometry.direction = FoilReliefMaterial.blendRidgeDirection(
                            geometry.direction, sample.direction, weight: sample.edge * 0.16)
                        if sample.light < 0.20 && sample.edge > 0.40 { responseWeight = 0.24 }
                        // Only part of each line, so it sparkles rather than
                        // outlining every ink edge in rainbow.
                        if material.hasPrismLinework && sample.edge > 0.36 && grain > 0.30 { prism = true }
                    } else {
                        let weight = material == .chrome || material == .printedRGB ? 1 : 0.40 + sample.edge * 0.50
                        geometry.direction = geometry.direction * (1 - weight) + sample.direction * weight
                        geometry.normal = sin(sample.light * 34 + geometry.direction * 2 + phase) * 2.6
                            + geometry.normal * 0.25
                        if material == .chrome {
                            geometry.normal = sin(sample.light * 7 + sample.direction * 0.55 + phase) * 2.6
                        }
                        geometry.color = sample.light * 0.40 + sample.direction * 0.09
                    }
                    responseWeight *= material.imageResponse(light: sample.light, edge: sample.edge)
                }
                let normalJitter = material.isIllustrationEtch || material.isEngraved ? 0.55 : (material.isMicroEtched ? 1.65 : 4.2)
                let normal = geometry.normal + (grain - 0.5) * normalJitter
                let halfLength = (material.facetLength + random() * material.lengthVariation) * 0.5
                let lightPhase: Double
                if let columns = material.lightNeighbourhoodColumns {
                    lightPhase = FoilAreaLighting.neighbourhoodPhase(x: x, y: y, seed: seed, columns: columns)
                        + (grain - 0.5) * (material.isGold ? 1.4 : 0.8)
                } else {
                    lightPhase = grain * .pi * 2
                }
                facets.append(Facet(x: x, y: y,
                                    normalCos: cos(normal), normalSin: sin(normal),
                                    halfVectorX: cos(geometry.direction) * halfLength,
                                    halfVectorY: sin(geometry.direction) * halfLength,
                                    bevelX: -sin(geometry.direction), bevelY: cos(geometry.direction),
                                    colorPhase: geometry.color + grain * 0.065,
                                    lightPhase: lightPhase,
                                    glint: grain > (material.isIllustrationEtch ? 0.93 : 0.98),
                                    responseWeight: responseWeight,
                                    prism: prism))
            }
        }
        cache.setObject(Surface(facets), forKey: key)
        return facets
    }

    private static func geometry(material: FoilReliefMaterial, x: Double,
                                 y: Double, phase: Double)
        -> (normal: Double, direction: Double, color: Double) {
        switch material {
        case .neoShining:
            // Neo Destiny's subject-only metallic surface is not the
            // diagonal diffraction sheet used by other refractor cards.
            let grain = sin(x * 149 + y * 211 + phase)
                * cos(x * 127 - y * 173 + phase)
            return (grain * 2.6, grain * .pi, 0)
        case .microEtched(let finish):
            return finish.geometry(x: x, y: y, phase: phase)
        case .illustration:
            // Geometry is laid out by the etched ridge sampler. Color domains
            // do not read printed lightness as either height or foil color.
            return (0, 0, sin(x * 4.1 + y * 3.7 + phase) * 0.20)
        case .gold(let pattern):
            switch pattern {
            case .megaGold:
                // Dense metal grain, not rectangular patches or rainbow
                // scratches. A scan cannot supply the exact emboss plate.
                let facet = sin(x * 739 + y * 1031 + phase)
                    * cos(x * 617 - y * 887 + phase)
                return (facet * 2.7, facet * .pi, facet * 0.1)
            case .bwGold:
                let facet = sin(floor(x * 18) * 2.4 + floor(y * 24) * 1.7 + phase)
                return (facet * 2.9, facet * 2.0, x * 0.2)
            case .xyGold:
                let hatch = sin((x + y * 0.76) * 31 + phase)
                return (hatch * 2.6, .pi * (hatch > 0 ? 0.24 : -0.24), y * 0.2)
            case .swordShieldGold:
                let groove = sin(x * 32 + sin(y * 9 + phase) * 1.4)
                return (groove * 2.8, .pi * 0.5 + sin(y * 12) * 0.15, x * 0.2)
            case .sunMoonGold:
                let angle = atan2((y - 0.48) / 0.717, x - 0.46)
                let radius = hypot(x - 0.46, (y - 0.48) / 0.717)
                return (sin(radius * 35 + phase) * 2.5 + angle * 0.4,
                        angle + .pi * 0.5, radius * 0.2)
            default:
                let wave = sin(y * 28 + sin(x * 14 + phase) * 1.6)
                let direction = cos(x * 14 + phase) * 0.55
                return (wave * 2.65 + x * 1.4, direction, y * 0.2)
            }
        case .linear(let pattern):
            switch pattern {
            case .verticalLine:
                return (sin(x * 97 + phase) * 2.4, .pi * 0.5, x * 0.05)
            case .sheen, .satin:
                return (sin((x + y * 0.717) * 76 + phase) * 2.3,
                        -.pi * 0.25, (x + y) * 0.03)
            case .tinsel:
                return (sin(y * 121 + phase) * 2.7, 0, y * 0.05)
            case .waterWeb:
                let ripple = sin(x * 24 + y * 13 + phase)
                return (sin(y * 170 + ripple * 4) * 2.3,
                        cos(x * 24 + y * 13 + phase) * 0.48, ripple * 0.10)
            default:
                return (sin(y * 118 + sin(x * 13 + phase) * 0.8) * 2.5,
                        cos(x * 13 + phase) * 0.055, y * 0.04)
            }
        case .engraved(let pattern, let texture):
            if pattern == .rainbowSplash || pattern == .cosmos || pattern == .stone {
                let cell = sin(x * 239 + y * 173 + phase) * cos(x * 151 - y * 227)
                return (cell * 2.7, cell * .pi, x * 0.31 + y * 0.27 + cell * 0.16)
            }
            if pattern == .vmaxRays {
                let fan = sin(x * 12 + phase) * cos(y * 15 - phase)
                return (sin(y * 283 + fan * 5) * 2.5,
                        fan * 1.4, fan * 0.12)
            }
            switch texture {
            case .sunMoonEtched:
                let curl = sin(x * 12 + y * 9 + phase) * 0.8
                return (sin(y * 311 + curl * 4) * 2.5,
                        curl + cos(y * 11 - x * 6) * 0.5, curl * 0.14)
            case .bwEtched:
                let wave = sin(x * 11 + phase) * 0.24
                return (sin((y + x * 0.28) * 297 + wave * 4) * 2.5,
                        wave + 0.28, sin(x * 5 + y * 4 + phase) * 0.2)
            case .xyEtched:
                let wave = sin(x * 17 + y * 9 + phase) * 0.38
                return (sin((y - x * 0.36) * 313 + wave * 3) * 2.5,
                        wave - 0.34, sin(y * 7 + phase) * 0.2)
            default:
                let wave = sin(x * 22 + y * 5 + phase) * 0.32
                return (sin(y * 307 + wave * 3.1) * 2.4 + x,
                        wave, x * 0.20 + y * 0.13)
            }
        case .chrome:
            // The actual printed contours own this relief direction. No
            // assumed centre, Poké Ball or energy emblem is redrawn here.
            return (sin(x * 39 + y * 27 + phase) * 2.4, 0, 0)
        case .classicEtched:
            let cell = sin(floor(x * 85) * 2.7 + floor(y * 117) * 1.9 + phase)
            return (cell * 2.7, cell * .pi, cell * 0.05)
        case .printedRGB:
            return (sin(x * 141 + y * 103 + phase) * 2.8, -.pi * 0.25, 0)
        case .white, .black:
            // Engraved fan ridges need a dark silver return on the white card
            // and a bright silver return on the black card, without color.
            let dx = x - 0.49
            let dy = (y - 0.43) / 0.717
            let radius = hypot(dx, dy)
            let angle = atan2(dy, dx)
            return (sin(radius * 28 + angle * 2.0 + phase) * 2.7,
                    angle + .pi * 0.5, 0)
        }
    }
}

/// BWR scans already contain card-specific engraving. Re-light those ridges
/// instead of drawing a procedural pattern over Reshiram or Zekrom.
@MainActor
struct ScannedFoilReliefLayer: View {
    let cardID: String
    let preloaded: NSImage?
    let isWhite: Bool
    let isMonochrome: Bool
    let tilt: TiltVector

    @State private var loaded: NSImage?
    @State private var loadedCardID: String?

    private var image: NSImage? {
        loadedCardID == cardID ? loaded : preloaded
    }

    /// Keep the scan's engraving, but light separate groups of ridge normals.
    /// A single gradient over luminance only changes the whole plate's brightness.
    var body: some View {
        ZStack {
            if let image {
                ScannedEmbossHighlights(source: image, cardID: cardID,
                    isWhite: isWhite, isMonochrome: isMonochrome, tilt: tilt)
            }
        }
        .task(id: cardID) {
            if preloaded != nil { return }
            let requestedCardID = cardID
            let image = await CardImageLoader.image(cardID: requestedCardID, hires: true)
            guard !Task.isCancelled else { return }
            loaded = image
            loadedCardID = requestedCardID
        }
    }
}
