// Offline silhouette proposals for manual inspection. Never imported into
// production until the card's mask has been viewed alongside its reference.
import AppKit
import Vision
import CoreImage

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let resource = root.appendingPathComponent("Sources/PokePackBar/Resources")
let art = try JSONSerialization.jsonObject(with: Data(contentsOf: resource.appendingPathComponent("card-art.json"))) as! [String: Any]
let images = art["images"] as! [String: [String: Any]]
let geo = try JSONSerialization.jsonObject(with: Data(contentsOf: resource.appendingPathComponent("foil-geometry.json"))) as! [String: Any]
let cards = geo["cards"] as! [String: [String: Any]]
for id in CommandLine.arguments.dropFirst(2) {
    let bounds = cards[id]?["art"] as? [Double] ?? [0.02, 0.035, 0.98, 0.95]
    guard let info = images[id],
          let image = NSImage(contentsOf: root.appendingPathComponent("local-assets/CardArt/" + (info["file"] as! String))),
          var cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("Missing original \(id)") }
    if cg.width > cg.height {
        let context = CGContext(data: nil, width: cg.height, height: cg.width,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: CGFloat(cg.height), y: 0)
        context.rotate(by: .pi / 2)
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        cg = context.makeImage()!
    }
    let crop = CGRect(x: bounds[0] * Double(cg.width), y: bounds[1] * Double(cg.height),
        width: (bounds[2] - bounds[0]) * Double(cg.width), height: (bounds[3] - bounds[1]) * Double(cg.height)).integral
    guard let artwork = cg.cropping(to: crop) else { fatalError("Bad crop \(id)") }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: artwork)
    do {
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            print("NO SUBJECT \(id)"); continue
        }
        let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        let ci = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        try context.writePNGRepresentation(of: ci, to: output.appendingPathComponent(id + ".png"),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let registration = [crop.minX / Double(cg.width), crop.minY / Double(cg.height),
                            crop.maxX / Double(cg.width), crop.maxY / Double(cg.height)]
        try JSONEncoder().encode(registration).write(to: output.appendingPathComponent(id + ".json"))
        print("PROPOSAL \(id) \(Int(crop.width))x\(Int(crop.height))")
    } catch { print("FAILED \(id): \(error)") }
}
