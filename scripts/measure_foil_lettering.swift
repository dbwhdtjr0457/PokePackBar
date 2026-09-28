// Read printed lettering positions; do not infer locations from rarity alone.
// swift scripts/measure_foil_lettering.swift CARD_ART_DIR OUTPUT_JSON
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("Expected CARD_ART_DIR OUTPUT_JSON") }
var output: [String: [[String: Any]]] = [:]
for number in 265...271 {
    let id = "me2pt5-\(number)"
    let url = URL(fileURLWithPath: args[1]).appendingPathComponent("\(id).jpg")
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["ja-JP", "en-US"]
    try VNImageRequestHandler(url: url).perform([request])
    output[id] = (request.results ?? []).compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let points = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
        return ["text": candidate.string, "confidence": candidate.confidence,
                "quad": points.map { [Double($0.x), Double(1 - $0.y)] }]
    }
}
try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .prettyPrinted])
    .write(to: URL(fileURLWithPath: args[2]), options: .atomic)
