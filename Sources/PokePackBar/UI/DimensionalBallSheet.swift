import SwiftUI

/// Unseen Forces' diffractive 3D balls are shaded volumes, not white target
/// outlines. This is a sheet approximation, not a scan of each reverse plate.
struct DimensionalBallSheet: View {
    let tilt: TiltVector

    static func response(x: Double, y: Double, tilt: TiltVector) -> Double {
        let phase = tilt.nx * 2.4 + tilt.ny * 1.9 + x * 1.7 + y * 0.9
        return 0.04 + 0.90 * pow(max(0, sin(phase)), 2)
    }

    var body: some View {
        Canvas { context, size in
            let step = size.width * 0.25
            let radius = step * 0.28
            for row in 0..<7 {
                for column in 0..<5 {
                    let nx = (Double(column) + (row.isMultiple(of: 2) ? 0.48 : 0.98)) * 0.25
                    let ny = (Double(row) + 0.5) * step / size.height
                    let center = CGPoint(x: nx * size.width, y: ny * size.height)
                    let rect = CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2)
                    let shape = Path(ellipseIn: rect)
                    let energy = Self.response(x: nx, y: ny, tilt: tilt)
                    let hue = 0.53 + tilt.nx * 0.28 + tilt.ny * 0.18
                    let cool = Color(hue: hue - floor(hue), saturation: 0.88, brightness: 1)
                    let warmHue = hue + 0.42
                    let warm = Color(hue: warmHue - floor(warmHue), saturation: 0.88, brightness: 1)
                    var sphere = context
                    sphere.opacity = energy
                    sphere.clip(to: shape)
                    sphere.fill(shape, with: .radialGradient(Gradient(colors: [
                        .white.opacity(0.74), cool.opacity(0.85), cool.opacity(0.38), .black.opacity(0.34),
                    ]), center: CGPoint(x: center.x - radius * (0.30 + tilt.nx * 0.20),
                                        y: center.y - radius * 0.30),
                        startRadius: 0, endRadius: radius * 1.65))
                    var lower = Path()
                    lower.move(to: CGPoint(x: rect.minX, y: center.y))
                    lower.addQuadCurve(to: CGPoint(x: rect.maxX, y: center.y),
                                       control: CGPoint(x: center.x, y: center.y + radius * 0.36))
                    lower.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    lower.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    lower.closeSubpath()
                    sphere.fill(lower, with: .radialGradient(Gradient(colors: [warm, warm.opacity(0.30), .clear]),
                        center: CGPoint(x: center.x - radius * 0.2, y: center.y + radius * 0.5),
                        startRadius: 0, endRadius: radius * 1.3))
                    var seam = Path()
                    seam.move(to: CGPoint(x: rect.minX, y: center.y))
                    seam.addQuadCurve(to: CGPoint(x: rect.maxX, y: center.y),
                                      control: CGPoint(x: center.x, y: center.y + radius * 0.36))
                    sphere.stroke(seam, with: .color(.black.opacity(0.48)), lineWidth: size.width * 0.003)
                    let button = CGRect(x: center.x - radius * 0.20, y: center.y - radius * 0.04,
                                        width: radius * 0.40, height: radius * 0.40)
                    sphere.fill(Path(ellipseIn: button), with: .color(cool.opacity(0.66)))
                    sphere.stroke(Path(ellipseIn: button), with: .color(.white.opacity(0.38)),
                                  lineWidth: size.width * 0.0015)
                }
            }
        }
        .mask { Image(decorative: FoilScanGlintCache.sheetGrain, scale: 1).resizable() }
    }
}
