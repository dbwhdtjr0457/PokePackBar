import Foundation

/// Lighting, not a material: preserve each foil's normals, palette and masks.
/// A broad off-card source must not stamp a moving circular hotspot on the art.
enum FoilAreaLighting {
    static func source(nx: Double, ny: Double) -> CGPoint {
        CGPoint(x: -0.45 - min(1, max(-1, nx)) * 0.20,
                y: -0.55 - min(1, max(-1, ny)) * 0.20)
    }

    static func facetIllumination(x: Double, y: Double, phase: Double, angle: Double,
                                  minimum: Double = 0.18) -> Double {
        // Spatial energy has no interior maximum. Card-locked local phases
        // select glints, instead of every ridge sharing one Gaussian light disk.
        let area = 0.82 + 0.10 * ((x - 0.5) * cos(angle) + (y - 0.5) * sin(angle))
        let glint = pow(max(0, cos(phase + angle * 0.7)), 4)
        return area * (minimum + (1 - minimum) * glint)
    }

    /// Smooth, irregular neighbourhoods of ridges catch light together. Compute
    /// once with the facet geometry, not during hover. Hue is deliberately not
    /// derived from this field: coherent light must not become rainbow bands.
    static func neighbourhoodPhase(x: Double, y: Double, seed: UInt64,
                                   columns: Double) -> Double {
        let sx = x * columns, sy = y * columns / 0.717
        let ix = Int(floor(sx)), iy = Int(floor(sy))
        let fx = sx - floor(sx), fy = sy - floor(sy)
        let tx = fx * fx * (3 - 2 * fx), ty = fy * fy * (3 - 2 * fy)
        func phase(_ dx: Int, _ dy: Int) -> Double {
            var hash = seed ^ (UInt64(bitPattern: Int64(ix + dx)) &* 0x9E3779B97F4A7C15)
                ^ (UInt64(bitPattern: Int64(iy + dy)) &* 0xBF58476D1CE4E5B9)
            hash = (hash ^ (hash >> 30)) &* 0xBF58476D1CE4E5B9
            hash = (hash ^ (hash >> 27)) &* 0x94D049BB133111EB
            hash ^= hash >> 31
            return Double(hash >> 11) / Double(1 << 53) * .pi * 2
        }
        // Interpolate unit vectors, not wrapped angles (0 and 2π are adjacent).
        let samples = [(phase(0, 0), (1 - tx) * (1 - ty)),
                       (phase(1, 0), tx * (1 - ty)),
                       (phase(0, 1), (1 - tx) * ty), (phase(1, 1), tx * ty)]
        let vx = samples.reduce(0.0) { $0 + cos($1.0) * $1.1 }
        let vy = samples.reduce(0.0) { $0 + sin($1.0) * $1.1 }
        return atan2(vy, vx)
    }

    static func directionalSource(nx: Double, ny: Double) -> CGPoint {
        let angle = -2.3 + nx * 1.8 + ny * 1.2
        return CGPoint(x: 0.5 + cos(angle) * 1.5, y: 0.5 + sin(angle) * 1.5)
    }
}
