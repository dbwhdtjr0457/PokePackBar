import AppKit
import CryptoKit
import ImageIO

/// Optional original scans used by explicit local audits. Distributed builds
/// keep only the manifest and fetch rendered variants from the managed CDN.
/// The manifest records actual source dimensions and hashes for foil metadata.
enum CardArtLibrary {
    // Some original scans crop to 595px, despite the nominal 600px format.
    static let minimumWidth = 580
    static let minimumHeight = 800

    struct Entry: Decodable, Sendable {
        let file: String
        let width: Int
        let height: Int
        let bytes: Int
        let sha256: String
        let sourceURL: String
    }
    struct Manifest: Decodable, Sendable { let images: [String: Entry] }

    static let entries: [String: Entry] = {
        guard let url = AppResources.bundle?.url(forResource: "card-art", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return [:] }
        return manifest.images
    }()

    static var root: URL? {
        if let path = ProcessInfo.processInfo.environment["PPB_CARD_ART_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return Bundle.main.resourceURL?.appendingPathComponent("CardArt", isDirectory: true)
    }

    static func fileURL(_ key: String) -> URL? {
        guard let entry = entries[key], entry.file == URL(fileURLWithPath: entry.file).lastPathComponent else { return nil }
        return root?.appendingPathComponent(entry.file)
    }

    static func data(_ key: String) -> Data? {
        guard let url = fileURL(key) else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func dimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }

    static func accepts(_ data: Data, hires: Bool) -> Bool {
        guard let size = dimensions(data), size.width > 0, size.height > 0 else { return false }
        return !hires || (min(size.width, size.height) >= minimumWidth && max(size.width, size.height) >= minimumHeight)
    }

    @MainActor
    static func image(_ data: Data, hires: Bool) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // Grid cards decode a small thumbnail from the same original. Detail
        // views retain the original pixels; neither path enlarges a source.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: hires ? 4096 : 360,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard var cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        if cgImage.width > cgImage.height {
            // BREAK and LEGEND scans are sometimes supplied horizontally.
            // Orient the physical card in the portrait holder, without a crop,
            // stretch, upscale, or any change to the stored source file.
            guard let context = CGContext(data: nil, width: cgImage.height, height: cgImage.width,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.translateBy(x: CGFloat(cgImage.height), y: 0)
            context.rotate(by: .pi / 2)
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            guard let portrait = context.makeImage() else { return nil }
            cgImage = portrait
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    @MainActor
    static func isHighResolution(_ image: NSImage) -> Bool {
        image.representations.contains {
            min($0.pixelsWide, $0.pixelsHigh) >= minimumWidth && max($0.pixelsWide, $0.pixelsHigh) >= minimumHeight
        }
    }

    /// Runs without WalletStore or a network request. Also used on the assembled
    /// app, so an accidentally omitted asset directory cannot be installed.
    static func verify(index: CardIndex, hashes: Bool = false) throws -> Int {
        let keys = Set(index.cards.map(\.id) + index.sets.map { "pack_\($0.id)" })
        guard keys == Set(entries.keys) else { throw LocalAudit.Failure(description: "Offline image manifest coverage mismatch") }
        for key in keys {
            guard let entry = entries[key], let url = fileURL(key),
                  FileManager.default.fileExists(atPath: url.path) else {
                throw LocalAudit.Failure(description: "Missing offline original: \(key)")
            }
            if hashes {
                let data = try Data(contentsOf: url)
                guard let size = dimensions(data), size.width == entry.width, size.height == entry.height,
                      (key.hasPrefix("pack_") || accepts(data, hires: true)),
                      SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == entry.sha256
                else { throw LocalAudit.Failure(description: "Invalid offline original: \(key)") }
            }
        }
        return keys.count
    }
}
