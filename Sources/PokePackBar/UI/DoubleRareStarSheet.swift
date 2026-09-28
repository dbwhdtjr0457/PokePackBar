import SwiftUI

/// Motif family compared with three differently tilted Miraidon ex 081/198
/// specimens. Positions are a stable sheet approximation, not factory plates.
/// Ordinary ex alone dispatches here; Tera, Mega and full-art etches do not.
struct DoubleRareStarSheet: View {
    let tilt: TiltVector

    struct Motif {
        let x: Double
        let y: Double
        let radius: Double
        let phase: Double
        let kind: Int
    }

    static let motifs: [Motif] = {
        var state: UInt64 = 0x4558_5354_4152
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 32) / Double(UInt32.max)
        }
        return (0..<260).map { _ in
            Motif(x: random(), y: random(), radius: 0.006 + pow(random(), 2) * 0.019,
                  phase: random() * 2 * .pi, kind: Int(random() * 5))
        }
    }()

    static func response(phase: Double, tilt: TiltVector) -> Double {
        // Different diffraction orientations reveal adjacent motifs at
        // different angles. No global opacity gate can erase the whole sheet.
        0.06 + 0.94 * pow(max(0, cos(phase + tilt.nx * 3.8 - tilt.ny * 2.6)), 2)
    }

    var body: some View {
        Canvas { context, size in
            let full = Path(CGRect(origin: .zero, size: size))
            let hue = (0.55 + tilt.nx * 0.31 + tilt.ny * 0.19 + 1)
                .truncatingRemainder(dividingBy: 1)
            // A restrained substrate, not the previous full-face white veil.
            context.blendMode = .screen
            context.fill(full, with: .radialGradient(
                Gradient(colors: [Color(hue: hue, saturation: 0.65, brightness: 1).opacity(0.22), .clear]),
                center: CGPoint(x: size.width * (0.5 - tilt.nx * 0.3),
                                y: size.height * (0.36 - tilt.ny * 0.24)),
                startRadius: 0, endRadius: size.width * 0.7))
            for motif in Self.motifs {
                let energy = Self.response(phase: motif.phase, tilt: tilt)
                let center = CGPoint(x: motif.x * size.width, y: motif.y * size.height)
                let radius = motif.radius * size.width
                let color = Color(hue: (hue + motif.phase / (2 * .pi)).truncatingRemainder(dividingBy: 1),
                                  saturation: 0.28 + (1 - energy) * 0.4, brightness: 1)
                var shape = Path()
                if motif.kind == 0 {
                    shape.addEllipse(in: CGRect(x: center.x - radius * 0.42,
                        y: center.y - radius * 0.42, width: radius * 0.84, height: radius * 0.84))
                } else {
                    let rays = motif.kind == 1 ? 4 : 8
                    for point in 0..<(rays * 2) {
                        let angle = Double(point) * .pi / Double(rays) + .pi / 8
                        let outer = point % 2 == 0
                        let rayLength = outer ? (point % 4 == 0 ? 1.0 : 0.72) : 0.21
                        let location = CGPoint(x: center.x + cos(angle) * radius * rayLength,
                                               y: center.y + sin(angle) * radius * rayLength)
                        if point == 0 { shape.move(to: location) } else { shape.addLine(to: location) }
                    }
                    shape.closeSubpath()
                }
                context.fill(shape, with: .color(color.opacity(0.10 + energy * 0.82)))
            }
        }
    }
}
