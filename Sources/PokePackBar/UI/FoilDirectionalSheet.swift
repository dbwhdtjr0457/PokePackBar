import SwiftUI

/// Smooth diffraction foil has a directional return, not etched glitter.
/// Keep the sheet coordinates fixed; move only the illumination and spectrum.
@MainActor
struct FoilDirectionalSheet: View {
    let pattern: FoilPattern
    let tilt: TiltVector

    static func point(pattern: FoilPattern, along: Double, across: Double) -> CGPoint {
        switch pattern {
        case .verticalLine:
            CGPoint(x: across, y: along)
        case .sheen, .satin:
            CGPoint(x: along, y: across - along * 0.717)
        case .waterWeb:
            CGPoint(x: along, y: across + sin(along * 17 + across * 9) * 0.008
                + sin(along * 7 - across * 15) * 0.004)
        case .mirage:
            CGPoint(x: along, y: across + sin(along * 12 + across * 8) * 0.002)
        default:
            CGPoint(x: along, y: across)
        }
    }

    var body: some View {
        Canvas { context, size in
            let density = 360
            let center = CGPoint(x: (0.46 - tilt.nx * 0.34) * size.width,
                                 y: (0.36 - tilt.ny * 0.26) * size.height)
            let angle = tilt.nx * 2.3 + tilt.ny * 1.8
            let hue = 0.54 + angle * 0.16
            // Different stripe orientations survive, but their pitch stays
            // microscopic (around one point at the normal 240pt card size).
            for row in -density...density * 2 {
                let across = Double(row) / Double(density)
                let phase = sin(Double(row) * 1.3247) * 2.4
                let response = 0.16 + 0.84 * pow(max(0, cos(angle + phase)), 2)
                let colorHue = hue + sin(Double(row) * 0.72) * 0.035
                let color = Color(hue: colorHue - floor(colorHue), saturation: 0.58, brightness: 1)
                var line = Path()
                for segment in 0...40 {
                    let p = Self.point(pattern: pattern, along: Double(segment) / 40,
                                       across: across)
                    let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
                    if segment == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                context.stroke(line, with: .color(.black.opacity(0.06 * (1 - response))),
                               lineWidth: size.width / 720)
                context.stroke(line, with: .radialGradient(Gradient(stops: [
                    .init(color: .white.opacity(response * 0.88), location: 0),
                    .init(color: color.opacity(response * 0.86), location: 0.30),
                    .init(color: color.opacity(response * 0.42), location: 0.63),
                    .init(color: .clear, location: 1),
                ]), center: center, startRadius: 0, endRadius: size.width * 0.64),
                    lineWidth: size.width / 620)
            }
        }
    }
}
