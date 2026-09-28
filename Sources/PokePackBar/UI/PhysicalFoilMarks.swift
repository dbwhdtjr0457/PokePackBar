import AppKit
import CryptoKit
import SwiftUI

/// Visible marks traced from identified printings. These are optical masks,
/// not factory emboss plates. Never substitute a font or invented symbol.
@MainActor
enum PhysicalFoilMarks {
    struct Template: Decodable {
        let referenceCount: Int
        let contours: [[[Double]]]
    }
    struct Registration: Decodable {
        let sha256: String
        let motif: String
        let transform: [Double]
        let referenceURL: String
        let referenceSHA256: String
        let registration: String
        let inliers: Int
    }
    struct Logo: Decodable {
        let file: String
        let width: Int
        let height: Int
        let sha256: String
        let sourceURL: String
    }
    private struct Manifest: Decodable {
        let version: Int
        let templates: [String: Template]
        let ascended: [String: Registration]
        let inkMasks: [String: [[[Double]]]]
        let exLogos: [String: Logo]
    }
    private static let manifest: Manifest? = {
        guard let url = AppResources.bundle?.url(forResource: "physical-foil-marks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(Manifest.self, from: data), value.version == 1 else { return nil }
        return value
    }()
    static var templates: [String: Template] { manifest?.templates ?? [:] }
    static var registrations: [String: Registration] { manifest?.ascended ?? [:] }
    static var logos: [String: Logo] { manifest?.exLogos ?? [:] }

    static func clipPrintedInk(context: inout GraphicsContext, cardID: String, size: CGSize) {
        guard let contours = manifest?.inkMasks[cardID] else { return }
        var clearPaper = Path(CGRect(origin: .zero, size: size))
        for contour in contours where contour.count >= 3 {
            for (index, point) in contour.enumerated() {
                guard point.count == 2 else { return }
                let p = CGPoint(x: point[0] * size.width, y: point[1] * size.height)
                if index == 0 { clearPaper.move(to: p) } else { clearPaper.addLine(to: p) }
            }
            clearPaper.closeSubpath()
        }
        context.clip(to: clearPaper, style: FillStyle(eoFill: true))
    }

    static func ascendedPath(cardID: String, ball: Bool, in size: CGSize) -> Path? {
        let finish = ball ? "patternedReverse" : "reverseHolo"
        guard let entry = registrations["\(cardID)#\(finish)"],
              entry.sha256 == CardArtLibrary.entries[cardID]?.sha256,
              entry.transform.count == 6, entry.transform.allSatisfy(\.isFinite),
              let template = templates[entry.motif], template.referenceCount >= 3 else { return nil }
        let m = entry.transform
        var path = Path()
        for contour in template.contours {
            guard contour.count >= 3 else { continue }
            for (index, p) in contour.enumerated() {
                guard p.count == 2, p.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
                let point = CGPoint(x: (m[0] * p[0] + m[1] * p[1] + m[2]) * size.width,
                                    y: (m[3] * p[0] + m[4] * p[1] + m[5]) * size.height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
        return path.isEmpty ? nil : path
    }

    private static var logoCache: [String: NSImage] = [:]
    static func logoImage(setID: String, monochrome: Bool = false) -> NSImage? {
        let key = "\(setID)#\(monochrome ? "silver" : "colour")"
        if let cached = logoCache[key] { return cached }
        guard let record = logos[setID], record.file == URL(fileURLWithPath: record.file).lastPathComponent,
              let url = AppResources.bundle?.resourceURL?.appendingPathComponent("foil-marks").appendingPathComponent(record.file),
              let data = try? Data(contentsOf: url),
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == record.sha256,
              var image = NSImage(data: data) else { return nil }
        if monochrome {
            guard let input = CIImage(data: data),
                  let gray = CIContext().createCGImage(input.applyingFilter("CIColorControls",
                    parameters: [kCIInputSaturationKey: 0]), from: input.extent) else { return nil }
            image = NSImage(cgImage: gray, size: NSSize(width: gray.width, height: gray.height))
        }
        logoCache[key] = image
        return image
    }

    static func usesColoredEXLogo(setID: String, rarity: String?) -> Bool {
        // The coloured early-EX stamp belongs to rare cards. Later stamps are
        // monochrome; rarity controls their foil, not the expansion's box colour.
        guard ["ex7", "ex8", "ex9", "ex10"].contains(setID) else { return false }
        return rarity?.hasPrefix("Rare") == true
    }

    static func drawEXStamp(context: inout GraphicsContext, cardID: String, setID: String, size: CGSize) {
        let coloured = usesColoredEXLogo(setID: setID, rarity: CardIndex.shared?.card(cardID)?.rarity)
        guard let image = logoImage(setID: setID, monochrome: !coloured), let logo = logos[setID] else { return }
        let art = FoilGeometry.artRect(cardID: cardID, in: size)
        // Preserve the wordmark's aspect ratio. This is frame-relative placement,
        // not a claim of individually measured placement for 980 physical cards.
        let width = min(art.width * 0.34, size.width * 0.27)
        let height = width * CGFloat(logo.height) / CGFloat(logo.width)
        let rect = CGRect(x: art.maxX - size.width * 0.018 - width,
                          y: art.maxY - size.height * 0.013 - height, width: width, height: height)
        var stamp = context
        stamp.opacity = 0.90
        stamp.draw(Image(nsImage: image), in: rect)
    }

    static func verify() throws {
        let expected = Set(ExpansionFoil.parallels.keys.flatMap { ["\($0)#reverseHolo", "\($0)#patternedReverse"] })
        try LocalAudit.require(templates.count == 16 && Set(registrations.keys) == expected && logos.count == 10,
            "Physical foil references are incomplete")
        for (key, entry) in registrations {
            let id = String(key.split(separator: "#")[0])
            guard let path = ascendedPath(cardID: id, ball: key.hasSuffix("#patternedReverse"),
                in: CGSize(width: 240, height: 335)) else {
                throw LocalAudit.Failure(description: "Physical mark lost registration: \(key)")
            }
            let bounds = path.boundingRect
            try LocalAudit.require(entry.inliers >= 14 && entry.referenceSHA256.count == 64
                && bounds.width > 80 && bounds.width < 145 && bounds.minY > 155 && bounds.maxY < 288,
                "Invalid physical mark registration: \(key)")
        }
        for n in 7...16 {
            try LocalAudit.require(logoImage(setID: "ex\(n)") != nil, "Invalid EX wordmark: ex\(n)")
            guard let mono = logoImage(setID: "ex\(n)", monochrome: true),
                  let cg = mono.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw LocalAudit.Failure(description: "Missing silver EX wordmark: ex\(n)")
            }
            let bitmap = NSBitmapImageRep(cgImage: cg)
            for y in stride(from: 0, to: cg.height, by: max(1, cg.height / 20)) {
                for x in stride(from: 0, to: cg.width, by: max(1, cg.width / 40)) {
                    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.5 else { continue }
                    try LocalAudit.require(abs(c.redComponent - c.greenComponent) < 0.015
                        && abs(c.greenComponent - c.blueComponent) < 0.015,
                        "Silver EX stamp still contains coloured pixels: ex\(n)")
                }
            }
        }
        for id in ["me2pt5-181"] {
            try LocalAudit.require(ascendedPath(cardID: id, ball: true, in: CGSize(width: 240, height: 335)) == nil
                && ascendedPath(cardID: id, ball: false, in: CGSize(width: 240, height: 335)) == nil,
                "Invented mark used without reference: \(id)")
        }
        print("PASS physical foil marks: 16 scan-traced motifs, all 280 source-bound registrations, 10 exact EX wordmarks; nonparallel printings remain unmarked")
    }
}

/// The printed wordmark survives every lighting angle. It must not be fed into
/// a generic alpha-only flash mask (that turns the PNG into a black silhouette)
/// or the artwork's travelling illumination (that erases the lower-right mark).
@MainActor
struct EXPrintedStampLayer: View {
    let cardID: String
    let finish: CardFinish

    var body: some View {
        if finish == .reverseHolo {
            Canvas { context, size in
                let setID = String(cardID.split(separator: "-", maxSplits: 1)[0])
                PhysicalFoilMarks.drawEXStamp(context: &context, cardID: cardID, setID: setID, size: size)
            }
        }
    }
}
