// Inspect the printed Tera label when provider metadata omits it. Read-only.
// swift scripts/audit_card_labels.swift INDEX CARD_ART_DIR SET_ID
import Foundation
import Vision
import ImageIO

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("Expected INDEX CARD_ART_DIR SET_ID") }
let index = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[1]))) as! [String: Any]
let root = URL(fileURLWithPath: args[2])
let cards = (index["cards"] as! [[Any]]).filter {
    ($0[0] as! String).hasPrefix(args[3] + "-") && ["RR", "SR", "SAR"].contains($0[2] as! String)
}
var tera: [String] = []
for row in cards {
    let id = row[0] as! String
    let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(id + ".json"))) as! [String: Any]
    let url = root.appendingPathComponent(sidecar["file"] as! String)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    request.regionOfInterest = CGRect(x: 0, y: 0.66, width: 1, height: 0.34)
    try VNImageRequestHandler(url: url).perform([request])
    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    if text.range(of: #"\btera\b"#, options: [.regularExpression, .caseInsensitive]) != nil { tera.append(id) }
}
print(String(decoding: try JSONSerialization.data(withJSONObject: ["checked": cards.count, "tera": tera], options: [.sortedKeys]), as: UTF8.self))
