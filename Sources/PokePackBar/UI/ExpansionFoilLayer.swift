import AppKit
import SwiftUI

/// Compound sheets never pass through the old full-face gradient/glare stack.
/// Each region keeps fixed registration; only local facets respond to tilt.
@MainActor
struct ExpansionFoilLayer: View {
    let treatment: FoilTreatment
    let cardID: String
    let source: NSImage
    let visualKind: CardVisualKind?
    let tilt: TiltVector
    let seed: UInt64

    var body: some View {
        switch treatment {
        case .classic30:
            ZStack {
                ZStack {
                    relief(.classicEtched).opacity(0.78)
                    AnniversaryFlakes(seed: seed, tilt: tilt, fireworks: false)
                }.mask { ClassicGoldMask(cardID: cardID, inverted: true) }
                ZStack {
                    relief(.gold(.megaGold)).opacity(0.95)
                    AnniversaryFlakes(seed: seed &+ 17, tilt: tilt, fireworks: false, goldOnly: true)
                }.mask { ClassicGoldMask(cardID: cardID) }
            }
        case .pikachu30:
            ZStack {
                relief(.linear(.satin)).opacity(0.55)
                AnniversaryFlakes(seed: seed, tilt: tilt, fireworks: true)
            }
        case .futuristic30:
            relief(.chrome)
        case .rgb30:
            relief(.printedRGB).opacity(0.88)
        case .megaDoubleRare:
            relief(.engraved(.mirage, .scarletVioletEtched)).opacity(0.76)
        case .ascendedEnergy, .ascendedBall:
            ZStack {
                relief(.linear(.mirage)).opacity(0.68)
                AscendedMark(cardID: cardID, ball: treatment == .ascendedBall,
                    tilt: tilt)
            }.mask { AscendedReverseMask(cardID: cardID) }
        }
    }

    private func relief(_ material: FoilReliefMaterial) -> some View {
        ImageGuidedFoilRelief(cardID: cardID, preloaded: source, material: material, seed: seed, tilt: tilt)
    }
}

struct ClassicGoldMask: View {
    let cardID: String
    var inverted = false

    var body: some View {
        Canvas { context, size in
            var path = Path()
            if inverted { path.addRect(CGRect(origin: .zero, size: size)) }
            for contour in ExpansionFoil.entries[cardID]?.goldFrame ?? [] {
                for (i, p) in contour.enumerated() {
                    let point = CGPoint(x: p[0] * size.width, y: p[1] * size.height)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
            }
            context.fill(path, with: .color(.white), style: FillStyle(eoFill: true))
        }
    }
}

private struct AscendedReverseMask: View {
    let cardID: String
    var body: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            if let art = FoilGeometry.illustrationPath(cardID: cardID, in: size) { path.addPath(art) }
            context.fill(path, with: .color(.white), style: FillStyle(eoFill: true))
        }
    }
}

/// Classic: small angular sparkle grains. Pikachu: fine radial fireworks, not
/// the old large cyan/pink confetti tiles or a rainbow gradient across the face.
private struct AnniversaryFlakes: View {
    let seed: UInt64
    let tilt: TiltVector
    let fireworks: Bool
    var goldOnly = false

    var body: some View {
        Canvas { context, size in
            var random = PackSeedGenerator(seed: seed)
            func next() -> Double { Double(random.next() >> 11) / Double(1 << 53) }
            let colors = goldOnly
                ? [Color(red: 1, green: 0.88, blue: 0.44), Color(red: 1, green: 0.98, blue: 0.80)]
                : [Color(red: 1, green: 0.88, blue: 0.59), Color(red: 0.67, green: 0.92, blue: 1),
                   Color(red: 1, green: 0.76, blue: 0.88), Color(white: 0.97)]
            let count = fireworks ? 260 : 1800
            for n in 0..<count {
                let x = next(), y = next(), normal = next() * .pi * 2
                let radius = size.width * (fireworks ? 0.007 + next() * 0.022 : 0.0009 + next() * 0.0021)
                let response = sin(normal + tilt.nx * 3.8 + tilt.ny * 2.7)
                let light = exp(-pow((x - 0.48 + tilt.nx * 0.18) / 0.65, 2)
                               - pow((y - 0.44 + tilt.ny * 0.16) / 0.82, 2))
                let opacity = (0.13 + pow(abs(response), 3) * 0.77) * (0.35 + light * 0.65)
                let center = CGPoint(x: x * size.width, y: y * size.height)
                var path = Path()
                if fireworks {
                    for ray in 0..<10 {
                        let angle = Double(ray) * .pi / 5 + normal
                        path.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.26,
                                             y: center.y + sin(angle) * radius * 0.26))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * radius,
                                                y: center.y + sin(angle) * radius))
                    }
                    context.stroke(path, with: .color(response > 0 ? colors[n % colors.count].opacity(opacity)
                        : Color(white: 0.10).opacity(opacity * 0.25)), lineWidth: size.width / 760)
                } else {
                    path.move(to: CGPoint(x: center.x - radius, y: center.y))
                    path.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.65))
                    path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.65))
                    path.closeSubpath()
                    context.fill(path, with: .color(response > 0 ? colors[n % colors.count].opacity(opacity)
                        : Color(red: 0.18, green: 0.12, blue: 0.04).opacity(opacity * 0.38)))
                }
            }
        }
    }
}

private struct AscendedMark: View {
    let cardID: String
    let ball: Bool
    let tilt: TiltVector

    var body: some View {
        Canvas { context, size in
            guard let path = PhysicalFoilMarks.ascendedPath(cardID: cardID, ball: ball, in: size) else { return }
            PhysicalFoilMarks.clipPrintedInk(context: &context, cardID: cardID, size: size)
            let rect = path.boundingRect
            let phase = tilt.nx * 2.8 + tilt.ny * 2.1
            // Actual filled/cut-out contours traced from multiple identified
            // international printings; registration follows this original scan.
            // Bright originals need a dark return too: additive white alone
            // erases the filled hemisphere and its small cut-outs on yellow ink.
            context.fill(path, with: .color(.black.opacity(0.10)), style: FillStyle(eoFill: true))
            context.stroke(path, with: .color(.black.opacity(0.15)), lineWidth: size.width / 600)
            context.fill(path, with: .linearGradient(Gradient(stops: [
                .init(color: .white.opacity(0.16 + max(0, sin(phase + 0.7)) * 0.30), location: 0),
                .init(color: .white.opacity(0.09), location: 0.48),
                .init(color: .black.opacity(0.12 + max(0, -sin(phase)) * 0.14), location: 1),
            ]), startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)),
                style: FillStyle(eoFill: true))
        }
    }
}
