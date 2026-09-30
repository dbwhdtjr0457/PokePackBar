// Offline packaging gate: inspect the actual pixels, not only filenames.
// swift scripts/audit_energy_art.swift PATH_TO_RESOURCES
import Foundation
import Vision
import ImageIO

struct AuditFailure: Error, CustomStringConvertible { let description: String }

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw AuditFailure(description: message) }
}

func recognizedText(_ url: URL, region: CGRect) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US", "ja-JP"]
    request.regionOfInterest = region
    try VNImageRequestHandler(url: url).perform([request])
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")
}

do {
    try require(CommandLine.arguments.count == 2, "Expected resource directory")
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let types = ["grass", "fire", "water", "lightning", "psychic", "fighting", "darkness", "metal"]
    var checked = 0
    for style in ["sm", "swsh", "sve", "mee", "mee30"] {
        for (offset, type) in (style == "sm" ? types + ["fairy"] : types).enumerated() {
            let mega = style == "mee" || style == "mee30"
            let name = "\(style)\(mega ? "-en" : "")-\(type).\(style == "sve" ? "png" : "jpg")"
            let url = root.appendingPathComponent(name)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int
            else { throw AuditFailure(description: "Missing or corrupt Energy art: \(name)") }
            try require(width >= 650 && height >= 900 && width < height, "Low-resolution art: \(name)")
            let title = try recognizedText(url, region: CGRect(x: 0, y: 0.72, width: 1, height: 0.28))
            try require(title.lowercased().contains("energy"), "Not an English Energy title: \(name): \(title)")
            try require(title.range(of: #"[\p{Hiragana}\p{Katakana}\p{Han}]"#,
                                    options: .regularExpression) == nil,
                        "Japanese text found: \(name): \(title)")
            if mega {
                let footer = try recognizedText(url, region: CGRect(x: 0, y: 0, width: 1, height: 0.18))
                let number = String(format: "%03d", offset + (style == "mee30" ? 9 : 1))
                try require(footer.contains(number), "Wrong MEE collector number: \(name): \(footer)")
            }
            print("PASS \(name): \(width)x\(height), English title")
            checked += 1
        }
    }
    for type in types {
        for ext in ["png", "webp"] {
            let oldName = "mee-\(type).\(ext)"
            try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(oldName).path),
                        "Obsolete non-English art remains: \(oldName)")
        }
    }
    print("PASS English supplemental Energy: \(checked) images; MEE 001–008 / anniversary 009–016")
} catch {
    fputs("Energy art audit failed: \(error)\n", stderr)
    exit(1)
}
