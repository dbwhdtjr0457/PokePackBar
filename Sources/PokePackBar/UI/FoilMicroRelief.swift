import SwiftUI

/// Etching families that previously reached the flat motif renderer. These
/// surfaces simulate material-scale relief, not a measured factory emboss plate.
/// The illustration may guide a ridge, but must not erase each sheet's geometry.
enum FoilMicroRelief: String, CaseIterable {
    case vstar
    case shinyGX
    case shinyV
    case shinyVMAX
    case shinyEx
    case teraShinyEx

    init?(pattern: FoilPattern) {
        switch pattern {
        case .vstarSheen: self = .vstar
        case .shinyGX: self = .shinyGX
        case .shinyV: self = .shinyV
        case .shinyVMAX: self = .shinyVMAX
        case .shinyEx: self = .shinyEx
        case .teraShinyEx: self = .teraShinyEx
        default: return nil
        }
    }

    var columns: Int {
        switch self {
        case .vstar: 268
        case .shinyGX: 276
        case .shinyV: 280
        case .shinyVMAX: 270
        case .shinyEx: 284
        case .teraShinyEx: 278
        }
    }

    var facetLength: Double {
        switch self {
        case .vstar: 0.44
        case .shinyGX: 0.40
        case .shinyV: 0.48
        case .shinyVMAX: 0.44
        case .shinyEx: 0.32
        case .teraShinyEx: 0.38
        }
    }

    var shadowStrength: Double {
        switch self {
        case .shinyEx, .teraShinyEx: 0.36
        case .vstar: 0.32
        default: 0.30
        }
    }

    var reflectionColors: [Color] {
        switch self {
        case .vstar:
            [Color(white: 1), Color(red: 0.78, green: 0.92, blue: 0.96),
             Color(red: 1, green: 0.92, blue: 0.68)]
        case .shinyGX:
            [Color(white: 1), Color(red: 0.67, green: 0.89, blue: 1),
             Color(red: 0.96, green: 0.79, blue: 0.91)]
        case .shinyV:
            [Color(white: 0.98), Color(red: 0.74, green: 0.97, blue: 0.89),
             Color(red: 0.80, green: 0.83, blue: 1)]
        case .shinyVMAX:
            [Color(white: 1), Color(red: 0.97, green: 0.78, blue: 0.93),
             Color(red: 0.67, green: 0.94, blue: 1), Color(red: 1, green: 0.92, blue: 0.73)]
        case .shinyEx:
            [Color(white: 1), Color(white: 0.84), Color(red: 0.83, green: 0.95, blue: 1)]
        case .teraShinyEx:
            [Color(white: 1), Color(red: 0.76, green: 0.91, blue: 1),
             Color(red: 0.93, green: 0.81, blue: 1), Color(red: 1, green: 0.93, blue: 0.76)]
        }
    }

    /// Normal/direction fields are card-locked; tilt is deliberately not an
    /// input. Only the response to light changes during pointer movement.
    func geometry(x: Double, y: Double, phase: Double)
        -> (normal: Double, direction: Double, color: Double) {
        switch self {
        case .vstar:
            let bend = sin(x * 18 + sin(y * 11 + phase) * 1.6)
            let contour = sin(y * 230 + bend * 12 + phase)
            return (contour * 2.7, bend * 0.65 + cos(y * 13) * 0.22,
                    bend * 0.12 + contour * 0.08)
        case .shinyGX:
            let curl = sin(x * 13 + y * 17 + phase)
            let ridge = sin((y - x * 0.58) * 260 + curl * 9)
            return (ridge * 2.6, -.pi * 0.28 + curl * 0.58,
                    curl * 0.16 + ridge * 0.07)
        case .shinyV:
            let bend = sin(y * 18 + phase) * 0.7 + sin(x * 11) * 0.3
            let ridge = sin(x * 300 + bend * 8)
            return (ridge * 2.8, .pi * 0.5 + bend * 0.3,
                    bend * 0.15 + ridge * 0.06)
        case .shinyVMAX:
            // Distributed local fans, never a guessed radial centre stamped
            // through the Pokémon's body on every VMAX illustration.
            let curl = sin(x * 14 + phase) * cos(y * 19 - phase)
            let direction = atan2(cos(y * 19 - phase) * 0.5, sin(x * 14 + phase) * 0.8)
            let fan = sin((x + y * 0.717) * 260 + curl * 11)
            return (fan * 2.65, direction, fan * 0.12 + curl * 0.13)
        case .shinyEx:
            // Short crossed facets retain a silver return on the white sheet;
            // unlike shiny V, they cannot merge into long vertical wires.
            let tile = sin(floor(x * 64) * 2.13 + floor(y * 88) * 1.67 + phase)
            let ridge = sin((x + y * 0.717) * 350 + tile * 2.5)
            return (ridge * 2.75, (tile > 0 ? 1 : -1) * .pi * 0.25 + tile * 0.18,
                    tile * 0.07)
        case .teraShinyEx:
            let tileX = floor(x * 38)
            let tileY = floor(y * 52)
            let crystal = sin(tileX * 2.71 + tileY * 1.83 + phase)
            let ridge = sin((x * 0.72 - y) * 320 + crystal * 3.1)
            let orientation = Double(Int(abs(crystal) * 6) % 3) * .pi / 3
            return (ridge * 2.8 + crystal * 0.25, orientation,
                    crystal * 0.2 + ridge * 0.08)
        }
    }
}
